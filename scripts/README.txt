
The website articles are generated using pandocpaper, but the index is generated from a helper script that finds files in the articles/ folder.

Adding or updating an article works as follows

```sh
$ scripts/helpers.sh paper path/to/filename.md
```

and then to update the index

```sh
$ scripts/helpers.sh webindex
```

