+++
title = "Understanding what new code does without reading it"
author = ["Petr Tikilyaynen"]
date = 2019-12-15T21:02:00+00:00
lastmod = 2019-12-16T00:46:48+00:00
tags = ["rust", "tantivy"]
categories = ["hacking"]
draft = false
description = "Weird tricks to avoid reading code"
+++

I recently started working on a ticket in tantivy that allows users to [customise
the weight of a field](https://github.com/tantivy-search/tantivy/issues/547) by increasing/decreasing the score of documents that match
the query in a specific field.

Tantivy is a rust library to build search engines and we are working on new features while keeping track of performance - [benchmarks here](https://tantivy-search.github.io/bench/).


## Previous understanding {#previous-understanding}

From working on the tantivy codebase before (including extending the range query
syntax), I have a high-level understanding of the cycle from query to SERPs (Search Engine Result Page).

My understanding so far:

> (Query comes in) -> (Query parsed to an AST consisting of several BooleanQuery instances)
>
> |  |
> |--|
> |  |
>
>                    V
> (Each BooleanQuery runs over the index)
>
> |  |
> |--|
> |  |
>
>                            V
> (Scores from sub-queries are combined in the top-level query)
>
> |  |
> |--|
> |  |
>
>                                  V
> (Relevant documents are retrieved, ordered by their score and returned)

Since this feature will require changing several components at the same time, I
will need to understand them in finer detail, so I don't change the semantics
unintentionally.

I also suspect that I am misunderstanding and/or missing stages in this pipeline, which will be roadblocks to implement this PR.


## How would you dig into this? {#how-would-you-dig-into-this}

Most people would sit down and read the code, going from function to function starting from the query being parsed.

I wanted to try something new instead.


## What am I going to do instead? {#what-am-i-going-to-do-instead}

I will create an example tantivy-based search application that runs user
provided queries. Running a debug build (with symbols preserved) application on a small index, I will collect a
trace and work through the stacktrace created by the query.


### Why? {#why}

Given the depth of the query lifecycle, I find it easier to observe a real
instance of the application and map it to the source code than reading the
source code to replay the situation in my head.

Also, I think it's fun to use other tools and see what else I might find.


## How are you going to do that? {#how-are-you-going-to-do-that}

Let's create a basic rust example that will work on an index (in a tempdir) and process queries.

```rust
// Taken from the basic_example.rs
use tantivy::collector::TopDocs;
use tantivy::query::QueryParser;
use tantivy::schema::*;
use tantivy::{doc, Index, ReloadPolicy};
use tempfile::TempDir;

fn main() -> tantivy::Result<()> {
    let index_path = TempDir::new()?;

    let mut schema_builder = Schema::builder();

    schema_builder.add_text_field("title", TEXT | STORED);

    schema_builder.add_text_field("body", TEXT);

    let schema = schema_builder.build();

    let index = Index::create_in_dir(&index_path, schema.clone())?;

    let mut index_writer = index.writer(50_000_000)?;

    let title = schema.get_field("title").unwrap();
    let body = schema.get_field("body").unwrap();

    let mut old_man_doc = Document::default();
    old_man_doc.add_text(title, "The Old Man and the Sea");
    old_man_doc.add_text(
        body,
        "He was an old man who fished alone in a skiff in the Gulf Stream and \
         he had gone eighty-four days now without taking a fish.",
    );

    index_writer.add_document(old_man_doc);

    index_writer.add_document(doc!(
    title => "Of Mice and Men",
    body => "A few miles south of Soledad, the Salinas River drops in close to the hillside \
            bank and runs deep and green. The water is warm too, for it has slipped twinkling \
            over the yellow sands in the sunlight before reaching the narrow pool. On one \
            side of the river the golden foothill slopes curve up to the strong and rocky \
            Gabilan Mountains, but on the valley side the water is lined with trees—willows \
            fresh and green with every spring, carrying in their lower leaf junctures the \
            debris of the winter’s flooding; and sycamores with mottled, white, recumbent \
            limbs and branches that arch over the pool"
    ));

    index_writer.add_document(doc!(
    title => "Of Mice and Men",
    body => "A few miles south of Soledad, the Salinas River drops in close to the hillside \
            bank and runs deep and green. The water is warm too, for it has slipped twinkling \
            over the yellow sands in the sunlight before reaching the narrow pool. On one \
            side of the river the golden foothill slopes curve up to the strong and rocky \
            Gabilan Mountains, but on the valley side the water is lined with trees—willows \
            fresh and green with every spring, carrying in their lower leaf junctures the \
            debris of the winter’s flooding; and sycamores with mottled, white, recumbent \
            limbs and branches that arch over the pool"
    ));

    index_writer.add_document(doc!(
    title => "Frankenstein",
    title => "The Modern Prometheus",
    body => "You will rejoice to hear that no disaster has accompanied the commencement of an \
             enterprise which you have regarded with such evil forebodings.  I arrived here \
             yesterday, and my first task is to assure my dear sister of my welfare and \
             increasing confidence in the success of my undertaking."
    ));

    index_writer.commit()?;

    let reader = index
        .reader_builder()
        .reload_policy(ReloadPolicy::OnCommit)
        .try_into()?;

    let searcher = reader.searcher();

    // We care about the functions in this block             ------------------|
    let query_parser = QueryParser::for_index(&index, vec![title, body]);  //  |
                                                                           //  |
    let query = query_parser.parse_query("sea whale")?;                    //  |
                                                                           //  |
    let top_docs = searcher.search(&query, &TopDocs::with_limit(10))?;     //  |
    //                                                      -------------------|

    for (_score, doc_address) in top_docs {
        let retrieved_doc = searcher.doc(doc_address)?;
        println!("{}", schema.to_json(&retrieved_doc));
    }

    Ok(())
}
```

So, I wrote this small example and only needed to run it with perf. However,
due to my machine setup I have to run a custom, newer than standard Ubuntu
version of the kernel (5.2.0-050200-generic), which doesn't have linux-tools in the apt repository.

Git cloned the linux kernel, checked out
0ecfebd2b52404ae0c54a878c872bb93363ada36, ran `make` in `/tools/perf` but it
came up with too few options.

It was time to say a word of appreciation for everyone involved in
seemless package management for major Linux distributions, which enables me
to `sudo apt install *` most packages without worrying about their
dependencies.


## Call with Paul {#call-with-paul}

Understanding of the code so far:

\`\`\`
let query = query\_parser.parse\_query("body:\\"shared by both\\" OR body:fish")?;
\`\`\`

A query comes in -> QueryParser converts it into a UserInputAST, consisting of several BooleanQuery instances -> Query makes a Weights for every SegmentCollector -> Every SegmentCollector creates fruits -> Fruits are merged into a top-K max-heap, which is returned

My questions are:

1.  Is the understanding above correct?
2.  Given a segment and a document, where does the score come from and how is it combined?
3.  Given a query with multiple subqueries - how are their scores combined?
4.  When a query has
