# Note: texrex is no longer maintained, will re-emerge as PyRex

As of December 2021, I've officially dropped support/maintenance for texrex. It's unnecessarily complex due to some quirks of working with Pascal in the 2020s. Also, as much as I like Pascal and the FreePascal compiler, the FreePascal ecosystem is outright annoying. Instead, I'll be working on [PyRex](https://github.com/rsling/PyRex), a modular Python 3 reimplementation of texrex with a focus on analysing CommonCrawl data. If things go well, NLP modules for German and English (such as currently available in [COWTek](https://github.com/rsling/cow)) might be added.

The ClaraX crawler will not be reimplemented in Python, but I'm planning to include some bias-removal tools in PyRex if CommonCrawl data allows for a good guess of at least some properties of the web graph.

The following is the old texrex README…

# texrex web page cleaning system

**Web document cleaning/crawl file processing tools written by Roland Schäfer for the COW project.**

**Current milestone: texrex-behindthecow (2015)**


texrex is a free software for processing data files from crawls and turn them into a corpus of web documents.
Currently, it is limited to reading ARC and WARC files, but other input modules can be developed quickly. 


It performs the following processing steps:

- read WARC or ARC files document by document
- filter perfect duplicates using a Bloom filter
- strip HTML, scripts, stylesheets
- extract meta information from crawl headers
- normalize encodings to UTF-8 (using ICU), optionally treating all ISO-8859-1 input as Win-1252
- convert all HTML entities to appropriate codepoints (including rogue Win-1252)
- detect, remove, and/or annotate boilerplate blocks using state-of-the-art classifier (http://rolandschaefer.net/?p=88)
- assess the text quality of the documents by looking at frequencies of short frequent word (http://rolandschaefer.net/?p=78)
- create w-shingling document fingerprints and filter near-duplicate documents
- perform in-document deduplication (remove repeated paragraphs, insert a backreference to first copy)
- perform additional normalization (e.g., reduce diverse Unicode dashes and hyphens to the basic codepoint)
- write standard-compliant XML output
- add server IP geolocation meta information (country, region, city – currently based on GeoLite)


Technologically, the main features of texrex are:

- written in FreePascal (Object FPC mode)
- licensed under permissive 2-clause BSD license
- uses multi-threading for single-machine parallelization
- uses simple INI files to configure processing jobs for the main tool
- can be run in the background, using an included IPC client to control the process
- depends only on two additional libraries: ICU and FANN


New tools included since texrex-neuedimensionen (June 2014):

- HyDRA hard hyphenation remover
- rofl tool to fix run-together sentences


Papers to read about texrex and related technology:

- http://rolandschaefer.net/?p=88
- http://rolandschaefer.net/?p=994
- http://rolandschaefer.net/?p=749
- http://rolandschaefer.net/?p=78
- http://rolandschaefer.net/?p=74
- http://rolandschaefer.net/?p=70


This repo was moved to GitHub from SourceForge r. 662 on May 1, 2016.
For reference:

https://sourceforge.net/p/texrex/code/HEAD/tree/
