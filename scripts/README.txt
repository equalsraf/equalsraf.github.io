
The website articles are generated using pandocpaper, but the index is generated from a helper script that finds files in the articles/ folder.

Adding or updating an article works as follows

```sh
$ make -f ../pandocpaper/Makefile INPUT_FILE=../pandocpaper/document.md html
(...)
$ cp out/html/document.html articles/filename.html
```

and then to update the index

```sh
$ source scripts/helpers.sh && webindex
```

