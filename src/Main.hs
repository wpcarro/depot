{-# LANGUAGE DeriveDataTypeable         #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE RecordWildCards            #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE TypeFamilies               #-}

module Main where

import           Control.Applicative          (optional, pure, (<$>), (<*>))
import           Control.Exception            (bracket)
import           Control.Monad                (liftM, msum, mzero, unless, when)
import           Control.Monad.IO.Class       (liftIO)
import           Control.Monad.Reader         (ask)
import           Control.Monad.State          (get, put)
import qualified Crypto.Hash.SHA512           as SHA
import           Data.Acid
import           Data.Acid.Advanced
import           Data.Acid.Local
import qualified Data.ByteString.Base64       as B64 (encode)
import           Data.ByteString.Char8        (ByteString, pack, unpack)
import           Data.Data                    (Data, Typeable)
import           Data.Maybe                   (fromJust)
import           Data.Monoid                  (mempty)
import           Data.SafeCopy                (base, deriveSafeCopy)
import           Data.Text                    (Text)
import qualified Data.Text                    as T
import           Data.Time
import           Happstack.Server             hiding (Session)
import           Happstack.Server.Compression
import           Options
import           System.Locale                (defaultTimeLocale)

import           Blog
import           BlogDB                       hiding (addComment, deleteComment,
                                               updateEntry)
import           Locales
import           RSS

{- Server -}

data MainOptions = MainOptions {
  optState :: String,
  optPort  :: Int
}

instance Options MainOptions where
  defineOptions = pure MainOptions
    <*> simpleOption "statedir" "/var/tazblog/"
        "Directory in which the BlogState is located."
    <*> simpleOption "port" 8000
        "Port to run on. Default is 8000."

tmpPolicy :: BodyPolicy
tmpPolicy = defaultBodyPolicy "./tmp/" 0 200000 1000

main :: IO()
main = do
    putStrLn ("TazBlog " ++ version ++ " in Haskell starting")
    runCommand $ \opts args ->
      bracket (openLocalStateFrom (optState opts ++ "BlogState") initialBlogState)
              createCheckpointAndClose
              (\acid -> simpleHTTP nullConf {port = optPort opts} $ tazBlog acid)

tazBlog :: AcidState Blog -> ServerPart Response
tazBlog acid = do
    compr <- compressedResponseFilter
    msum [ path $ \(lang :: BlogLang) -> blogHandler acid lang
         , nullDir >> showIndex acid EN
         , dir " " $ nullDir >>
            seeOther ("https://plus.google.com/115916629925754851590" :: Text) (toResponse ())
         , path $ \(year :: Int) -> path $ \(month :: Int) -> path $ \(id_ :: String) -> formatOldLink year month id_
         , dir "res" $ serveDirectory DisableBrowsing [] "../res"
         , dir "notice" $ ok $ toResponse showSiteNotice
         {- :Admin handlers -}
         , do dirs "admin/postentry" nullDir
              guardSession acid
              postEntry acid
         , do dirs "admin/entrylist" $ dir (show DE) nullDir
              guardSession acid
              entryList acid DE
         , do dirs "admin/entrylist" $ dir (show EN) nullDir
              guardSession acid
              entryList acid EN
         , do guardSession acid
              dirs "admin/edit" $ path $ \(eId :: Integer) -> editEntry acid eId
         , do guardSession acid
              dirs "admin/updateentry" $ nullDir >> updateEntry acid
         , do guardSession acid
              dirs "admin/cdelete" $ path $ \(eId :: Integer) -> path $ \(cId :: String) ->
                deleteComment acid (EntryId eId) cId
         , do dir "admin" nullDir
              guardSession acid
              ok $ toResponse $ adminIndex ("tazjin" :: Text)
         , dir "admin" $ ok $ toResponse adminLogin
         , dir "dologin" $ processLogin acid
         , do dirs "static/blogv40.css" nullDir
              setHeaderM "content-type" "text/css"
              setHeaderM "cache-control" "max-age=630720000"
              setHeaderM "expires" "Tue, 20 Jan 2037 04:20:42 GMT"
              ok $ toResponse blogStyle
         , do setHeaderM "cache-control" "max-age=630720000"
              setHeaderM "expires" "Tue, 20 Jan 2037 04:20:42 GMT"
              dir "static" $ serveDirectory DisableBrowsing [] "../res"
         , serveDirectory DisableBrowsing [] "../res"
         , notFound $ toResponse $ showError NotFound DE
         ]

blogHandler :: AcidState Blog -> BlogLang -> ServerPart Response
blogHandler acid lang =
    msum [ path $ \(eId :: Integer) -> showEntry acid lang $ EntryId eId
         , nullDir >> showIndex acid lang
         , dir "rss" $ nullDir >> showRSS acid lang
         , dir "rss.xml" $ nullDir >> showRSS acid lang
         , notFound $ toResponse $ showError NotFound lang
         ]

formatOldLink :: Int -> Int -> String -> ServerPart Response
formatOldLink y m id_ =
  flip seeOther (toResponse ()) $
    concat $ intersperse' "/"  ["de", show y, show m, replace '.' '/' id_]

showEntry :: AcidState Blog -> BlogLang -> EntryId -> ServerPart Response
showEntry acid lang eId = do
    entry <- query' acid (GetEntry eId)
    tryEntry entry lang

tryEntry :: Maybe Entry -> BlogLang -> ServerPart Response
tryEntry Nothing lang = notFound $ toResponse $ showError NotFound lang
tryEntry (Just entry) _ = ok $ toResponse $ blogTemplate eLang eTitle $ renderEntry entry
    where
        eTitle = T.append ": " (title entry)
        eLang = lang entry

showIndex :: AcidState Blog -> BlogLang -> ServerPart Response
showIndex acid lang = do
    entries <- query' acid (LatestEntries lang)
    (page :: Maybe Int) <- optional $ lookRead "page"
    ok $ toResponse $ blogTemplate lang "" $
        renderEntries False (eDrop page entries) (topText lang) (Just $ showLinks page lang)
  where
    eDrop :: Maybe Int -> [a] -> [a]
    eDrop (Just i) = drop ((i-1) * 6)
    eDrop Nothing = drop 0

showRSS :: AcidState Blog -> BlogLang -> ServerPart Response
showRSS acid lang = do
    entries <- query' acid (LatestEntries lang)
    feed <- liftIO $ renderFeed lang $ take 6 entries
    setHeaderM "content-type" "text/xml"
    ok $ toResponse feed

{- ADMIN stuff -}

postEntry :: AcidState Blog -> ServerPart Response
postEntry acid = do
    decodeBody tmpPolicy
    now <- liftIO getCurrentTime
    let eId = timeToId now
    lang <- look "lang"
    nBtext <- lookText' "btext"
    nMtext <- lookText' "mtext"
    nEntry <- Entry <$> pure eId
                    <*> getLang lang
                    <*> readCookieValue "sUser"
                    <*> lookText' "title"
                    <*> pure nBtext
                    <*> pure nMtext
                    <*> pure now
                    <*> pure [] -- NYI
                    <*> pure []
    update' acid (InsertEntry nEntry)
    seeOther ("/" ++ lang ++ "/" ++ show eId) (toResponse())
  where
    timeToId :: UTCTime -> EntryId
    timeToId t = EntryId . read $ formatTime defaultTimeLocale "%s" t
    getLang :: String -> ServerPart BlogLang
    getLang "de" = return DE
    getLang "en" = return EN

entryList :: AcidState Blog -> BlogLang -> ServerPart Response
entryList acid lang = do
    entries <- query' acid (LatestEntries lang)
    ok $ toResponse $ adminEntryList entries

editEntry :: AcidState Blog -> Integer -> ServerPart Response
editEntry acid i = do
    (Just entry) <- query' acid (GetEntry eId)
    ok $ toResponse $ editPage entry
  where
    eId = EntryId i

updateEntry :: AcidState Blog -> ServerPart Response -- TODO: Clean this up
updateEntry acid = do
    decodeBody tmpPolicy
    (eId :: Integer) <- lookRead "eid"
    (Just entry) <- query' acid (GetEntry $ EntryId eId)
    nTitle <- lookText' "title"
    nBtext <- lookText' "btext"
    nMtext <- lookText' "mtext"
    let nEntry = entry { title = nTitle
                        , btext = nBtext
                        , mtext = nMtext}
    update' acid (UpdateEntry nEntry)
    seeOther (concat $ intersperse' "/" [show $ lang entry, show eId])
             (toResponse ())

deleteComment :: AcidState Blog -> EntryId -> String -> ServerPart Response
deleteComment acid eId cId = do
    nEntry <- update' acid (DeleteComment eId cDate)
    ok $ toResponse $ commentDeleted eId
  where
    (cDate :: UTCTime) = fromJust $ parseTime defaultTimeLocale "%s%Q" cId

guardSession :: AcidState Blog -> ServerPartT IO ()
guardSession acid = do
    (sId :: Text) <- readCookieValue "session"
    (uName :: Text) <- readCookieValue "sUser"
    now <- liftIO getCurrentTime
    mS <- query' acid (GetSession $ SessionID sId)
    case mS of
      Nothing -> mzero
      (Just Session{..}) -> unless ((uName == username user) && sessionTimeDiff now sdate)
                                   mzero
  where
    sessionTimeDiff :: UTCTime -> UTCTime -> Bool
    sessionTimeDiff now sdate = diffUTCTime now sdate < 43200


processLogin :: AcidState Blog -> ServerPart Response
processLogin acid = do
    decodeBody tmpPolicy
    account <- lookText' "account"
    password <- look "password"
    login <- query' acid (CheckUser (Username account) password)
    if login
      then createSession account
      else ok $ toResponse adminLogin
  where
    createSession account = do
      now <- liftIO getCurrentTime
      let sId = hashString $ show now
      addCookie (MaxAge 43200) (mkCookie "session" $ unpack sId)
      addCookie (MaxAge 43200) (mkCookie "sUser" $ T.unpack account)
      (Just user) <- query' acid (GetUser $ Username account)
      let nSession = Session (T.pack $ unpack sId) user now
      update' acid (AddSession nSession)
      seeOther ("/admin?do=login" :: Text) (toResponse())

