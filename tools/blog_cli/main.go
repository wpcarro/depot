// The tazblog CLI implements updating my blog records in DNS, see the
// README in this folder for details.
//
// The post input format is a file with the title on one line,
// followed by the date on a line, followed by an empty line, followed
// by the post text.
package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"time"

	"google.golang.org/api/dns/v1"
)

var (
	project = flag.String("project", "tazjins-infrastructure", "Target GCP project")
	zone    = flag.String("zone", "blog-tazj-in", "Target Cloud DNS zone")
	title   = flag.String("title", "", "Title of the blog post")
	date    = flag.String("date", "", "Date the post was written on")
	infile  = flag.String("text", "", "Text file containing the blog post")
	id      = flag.String("id", "", "Post ID - will be generated if unset")
)

// Number of runes to include in a single chunk. If any chunks exceed
// the limit of what can be encoded, the chunk size is reduced and we
// try again.
var chunkSize = 200

type day time.Time

func (d day) MarshalJSON() ([]byte, error) {
	j := (time.Time(d)).Format(`"2006-01-02"`)
	return []byte(j), nil
}

type metadata struct {
	Chunks int    `json:"c"`
	Title  string `json:"t"`
	Date   day    `json:"d"`
}

type chunk struct {
	Chunk int
	Text  string
}

type post struct {
	ID     string
	Meta   metadata
	Chunks []string
}

func (p *post) writeToDNS() error {
	var additions []*dns.ResourceRecordSet
	additions = append(additions, &dns.ResourceRecordSet{
		Name: fmt.Sprintf("_meta.%s.blog.tazj.in.", p.ID),
		Type: "TXT",
		Ttl:  1200,
		Rrdatas: []string{
			encodeJSON(p.Meta),
		},
	})

	for i, c := range p.Chunks {
		additions = append(additions, &dns.ResourceRecordSet{
			Name:    fmt.Sprintf("_%v.%s.blog.tazj.in.", i, p.ID),
			Type:    "TXT",
			Ttl:     1200,
			Rrdatas: []string{c},
		})
	}

	ctx := context.Background()
	dnsSvc, err := dns.NewService(ctx)
	if err != nil {
		return err
	}

	change := dns.Change{
		Additions: additions,
	}

	_, err = dnsSvc.Changes.Create(*project, *zone, &change).Do()
	if err != nil {
		return err
	}

	return nil
}

// Encode given value as JSON and base64-encode it.
func encodeJSON(v interface{}) string {
	outer, err := json.Marshal(v)
	if err != nil {
		log.Fatalln("Failed to encode JSON", err)
	}

	return base64.RawStdEncoding.EncodeToString(outer)
}

// Encode a chunk and check whether it is too large
func encodeChunk(c chunk) (string, bool) {
	tooLarge := false
	s := base64.RawStdEncoding.EncodeToString([]byte(c.Text))

	if len(s) >= 255 {
		tooLarge = true
	}

	return s, tooLarge
}

func createPost(id, title, text string, date day) post {
	runes := []rune(text)
	n := 0
	tooLarge := false

	var chunks []string

	for chunkSize < len(runes) {
		c, l := encodeChunk(chunk{
			Chunk: n,
			Text:  string(runes[0:chunkSize:chunkSize]),
		})

		tooLarge = tooLarge || l
		chunks = append(chunks, c)
		runes = runes[chunkSize:]
		n++
	}

	if len(runes) > 0 {
		c, l := encodeChunk(chunk{
			Chunk: n,
			Text:  string(runes),
		})

		tooLarge = tooLarge || l
		chunks = append(chunks, c)
		n++
	}

	if tooLarge {
		log.Println("Too large at chunk size", chunkSize)
		chunkSize -= 5
		return createPost(id, title, text, date)
	}

	return post{
		ID: id,
		Meta: metadata{
			Chunks: n,
			Title:  title,
			Date:   date,
		},
		Chunks: chunks,
	}
}

func main() {
	flag.Parse()

	if *title == "" {
		log.Fatalln("Post title must be set (-title)")
	}

	if *infile == "" {
		log.Fatalln("Post text file must be set (-text)")
	}

	if *id == "" {
		log.Fatalln("Post ID must be set (-id)")
	}

	var postDate day
	if *date != "" {
		t, err := time.Parse("2006-01-02", *date)
		if err != nil {
			log.Fatalln("Invalid post date", err)
		}

		postDate = day(t)
	} else {
		postDate = day(time.Now())
	}

	t, err := ioutil.ReadFile(*infile)
	if err != nil {
		log.Fatalln("Failed to read post:", err)
	}

	post := createPost(*id, *title, string(t), postDate)

	log.Println("Writing post to DNS ...")
	err = post.writeToDNS()

	if err != nil {
		log.Fatalln("Failed to write post:", err)
	}

	log.Println("Successfully wrote entries")
}
