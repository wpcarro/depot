{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

-- |This module implements fetching of individual blog entries from
-- DNS. Yes, you read that correctly.
--
-- Each blog post is stored as a set of records in a designated DNS
-- zone. For the production blog, this zone is `blog.tazj.in.`.
--
-- A top-level record at `_posts` contains a list of all published
-- post IDs.
--
-- For each of these post IDs, there is a record at `_meta.$postID`
-- that contains the title and number of post chunks.
--
-- For each post chunk, there is a record at `_$chunkID.$postID` that
-- contains a base64-encoded post fragment.
--
-- This module implements logic for assembling a post out of these
-- fragments and caching it based on the TTL of its `_meta` record.
module BlogStore
  ( BlogCache,
    EntryId (..),
    Entry (..),
    withCache,
    listEntries,
    getEntry,
    show'
    )
where

import Control.Applicative ((<$>), (<*>))
import Control.Monad (mzero)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Data.Aeson ((.:), FromJSON (..), Value (Object), decodeStrict)
import Data.ByteString.Base64 (decodeLenient)
import Data.Either (fromRight)
import Data.List (sortBy)
import Data.Text as T (Text, concat, pack)
import Data.Text.Encoding (decodeUtf8', encodeUtf8)
import Data.Time (Day)
import Network.DNS (DNSError, lookupTXT)
import qualified Network.DNS.Resolver as R

newtype EntryId = EntryId {unEntryId :: Integer}
  deriving (Eq, Ord, FromJSON)

instance Show EntryId where

  show = show . unEntryId

data Entry
  = Entry
      { entryId :: EntryId,
        author :: Text,
        title :: Text,
        text :: Text,
        edate :: Day
        }
  deriving (Eq, Ord, Show)

-- | Wraps a DNS resolver with caching configured. For the initial
-- version of this, all caching of entries is done by the resolver
-- (i.e. no pre-assembled versions of entries are cached).
data BlogCache = BlogCache R.Resolver Text

data StoreError
  = PostNotFound EntryId
  | DNS DNSError
  | InvalidMetadata
  | InvalidChunk
  | InvalidPosts
  deriving (Show)

type Offset = Int

type Count = Int

withCache :: Text -> (BlogCache -> IO a) -> IO a
withCache zone f = do
  let conf =
        R.defaultResolvConf
          { R.resolvCache = Just R.defaultCacheConf,
            R.resolvConcurrent = True
            }
  seed <- R.makeResolvSeed conf
  R.withResolver seed (\r -> f $ BlogCache r zone)

listEntries :: MonadIO m => BlogCache -> Offset -> Count -> m [Entry]
listEntries cache offset count = liftIO $ do
  posts <- postList cache
  entries <- mapM (entryFromDNS cache) $ take count $ drop offset $ fromRight (error "no posts") posts
  -- TODO: maybe don't just drop broken entries
  return
    $ fromRight (error "no entries")
    $ sequence entries

getEntry :: MonadIO m => BlogCache -> EntryId -> m (Maybe Entry)
getEntry cache eid = liftIO $ entryFromDNS cache eid >>= \case
  Left _ -> return Nothing -- TODO: ??
  Right entry -> return $ Just entry

show' :: Show a => a -> Text
show' = pack . show

-- * DNS fetching implementation
type Chunk = Integer

-- | Represents the metadata stored for each post in the _meta record.
data Meta = Meta Integer Text Day
  deriving (Show)

instance FromJSON Meta where

  parseJSON (Object v) =
    Meta
      <$> v
      .: "c"
      <*> v
      .: "t"
      <*> v
      .: "d"
  parseJSON _ = mzero

entryMetadata :: BlogCache -> EntryId -> IO (Either StoreError Meta)
entryMetadata (BlogCache r z) (EntryId eid) =
  let domain = encodeUtf8 ("_meta." <> show' eid <> "." <> z)
      record = lookupTXT r domain
      toMeta rrdata = case decodeStrict $ decodeLenient rrdata of
        Nothing -> Left InvalidMetadata
        Just m -> Right m
   in record >>= \case
        (Left err) -> return $ Left $ DNS err
        (Right [bs]) -> return $ toMeta bs
        _ -> return $ Left InvalidMetadata

entryChunk :: BlogCache -> EntryId -> Chunk -> IO (Either StoreError Text)
entryChunk (BlogCache r z) (EntryId eid) c =
  let domain = encodeUtf8 ("_" <> show' c <> "." <> show' eid <> "." <> z)
      record = lookupTXT r domain
      toChunk rrdata = case decodeUtf8' $ decodeLenient rrdata of
        Left _ -> Left InvalidChunk
        Right chunk -> Right chunk
   in record >>= \case
        (Left err) -> return $ Left $ DNS err
        (Right [bs]) -> return $ toChunk bs
        _ -> return $ Left InvalidChunk

fetchAssembleChunks :: BlogCache -> EntryId -> Meta -> IO (Either StoreError Text)
fetchAssembleChunks cache eid (Meta n _ _) = do
  chunks <- mapM (entryChunk cache eid) [0 .. (n - 1)]
  return $ fmap T.concat $ sequence chunks

entryFromDNS :: BlogCache -> EntryId -> IO (Either StoreError Entry)
entryFromDNS cache eid = do
  meta <- entryMetadata cache eid
  case meta of
    Left err -> return $ Left err
    Right meta -> do
      chunks <- fetchAssembleChunks cache eid meta
      let (Meta _ t d) = meta
      return
        $ either Left
            ( \text -> Right $ Entry
                { entryId = eid,
                  author = "tazjin",
                  title = t,
                  text = text,
                  edate = d
                  }
              )
            chunks

postList :: BlogCache -> IO (Either StoreError [EntryId])
postList (BlogCache r z) =
  let domain = encodeUtf8 ("_posts." <> z)
      record = lookupTXT r domain
      toPosts =
        fmap (sortBy (flip compare))
          . mapM (maybe (Left InvalidPosts) Right . decodeStrict)
   in either (Left . DNS) toPosts <$> record
