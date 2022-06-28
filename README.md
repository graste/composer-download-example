# composer-download-example

Various examples on how to download external non-php dependencies via [composer](https://getcomposer.org). Please note, that the shell scripting examples use linux/bash.

```
tree
composer install
tree public
composer clean
```

See [`composer.json`](composer.json) for some methods to download files.

1. Let Composer download a file via custom repository/package
2. Let Composer download a zip file via custom repository/package
3. Direct download via `scripts`
4. Direct download via `scripts` with checksums
5. Direct download via custom bash script
6. Composer plugin to use PHP instead of bash and maybe create commands

## Let Composer download a file via custom repository/package

Composer works with repositories and packages. It defaults to [packagist.org](https://packagist.org), but allows definition of custom repositories and packages in root `composer.json` files. You define a custom repository with a package name and version and a `dist` location of type `file` with URL and checksum:

```json
{
    "require": {
        "external/file": "1.0.0"
    },
    "repositories": [
        {
            "type": "package",
            "package": {
                "name": "external/file",
                "version": "1.0.0",
                "dist": {
                    "url": "https://example.com/some/file.js",
                    "type": "file",
                    "shasum": "72a7dbfc8aa2c8de4810c73fb601e77cf289e673"
                }
            }
        }
    ]
}
```

A call to `composer [install|update]` will download the file from the given URL, verify the expected checksum and put the file into the `vendor/external/file` folder. You may then copy the file via e.g. [`post-install-cmd`](https://getcomposer.org/doc/articles/scripts.md#command-events) or create a symlink in your project with a relative path to that file in the vendor directory.

## Let Composer download a zip file via custom repository/package

Composer cannot only download single files via custom repositories and packages in root `composer.json` files. You may define a custom repository with a package name and version and a `dist` location of type `zip` with URL and checksum:

```json
{
    "require": {
        "external/zip": "1.0.0"
    },
    "repositories": [
        {
            "type": "package",
            "package": {
                "name": "external/zip",
                "version": "1.0.0",
                "dist": {
                    "url": "https://example.com/some/file.zip",
                    "type": "zip",
                    "shasum": "d620740b7d12b3d8238a28c4d2f2a3950b812d1e"
                }
            }
        }
    ]
}
```

A call to `composer [install|update]` will download the zip file from the given URL, verify the expected checksum and put the contents of the archive file into the `vendor/external/zip` folder. You may then copy single files from that folder via e.g. [`post-install-cmd`](https://getcomposer.org/doc/articles/scripts.md#command-events) or create a symlink in your project with a relative path to that folder or some of its files in the vendor directory.

## Direct download via `scripts`

Define script with one or multiple commands in [`scripts`](https://getcomposer.org/doc/articles/scripts.md#scripts) section:

```json
{
  "scripts": {
    "wget-files": [
      "wget https://example.com/some/file.js -O public/js/file.js",
      "wget https://example.com/some/otherfile.js -O public/js/otherfile.js"
    ]
  }
}
```

Run it either

1. manually via commandline: `composer [run-script] [your-script-name]`
2. or by referencing the script by name in other composer script listeners that are executed before/after some events (like `"post-install-cmd": "@your-script-name"`).

Composer fails the command if one line of the script fails with some non-zero exit code.

## Direct download via `scripts` with checksums

The above works, but doesn't verify that the downloaded files are the ones one expects to get. Thus checksum verification should be added per line or after the download of all files.

Per line via some bash script:

```
t=$(mktemp) && wget 'https://example.com/some/file.js' -qO "$t" && if sha256sum "$t" | cmp -s checksums.txt ; then mv "$t" target/file.js; else exit 1; fi; rm "$t"
```

Which is something that is hard to read, hard to maintain and lots of code when downloading multiple files.

That's why downloading files with checksum verification afterwards could be done like this:

```json
{
  "scripts": {
    "wget-files": [
      "wget https://example.com/some/file.js -O public/js/file.js",
      "wget https://example.com/some/otherfile.js -O public/js/otherfile.js"
      "sha256sum checksums.txt"
    ]
  }
}
```

The `checksums.txt` contains one line per file with `THE-ACTUAL-CHECKSUM path/to/file.js` entries. When the checksum verification fails, the composer script fails. The files will be left in place, which is maybe not wanted.

## Direct download via custom bash script

As the above is a bit verbose and one might want to prevent larger scripting operations in the `composer.json` file one solution is to create a shell script and reference that:

```json
{
  "scripts": {
    "wget-files": "bin/wget-packages.sh"
  }
}
```

The shell script uses a [`package.txt`](package.txt) file that has one line per file with source URL, target path locally and expected sha1 checksum. The script downloads the files into a temporary place and moves them to the target location when the checksum is valid. This method is preferable as one can customize the error handling, whether downloaded files with wrong checksums are deleted etc.

## Composer plugin to use PHP instead of bash and maybe create commands

When all of the above is either to verbose (multiple custom repositories or extensive shell scripting) or it's not working as not all target environments even have bash scripting capabilities there's the option to write [Composer plugins](https://getcomposer.org/doc/articles/plugins.md). Plugins can expand Composer's functionalities. They're written in PHP and can be published as normal Composer packages ([Plugin Package](https://getcomposer.org/doc/articles/plugins.md#plugin-package)). That is, your project can either have a plugin defined locally or use a packaged plugin. Plugins can be run manually in the same way as running Composer scripts. To be able to use a plugin in your project you need to [allow the plugin to be used](https://getcomposer.org/doc/06-config.md#allow-plugins) in the `composer.json` file.

```json
{
    "config": {
        "allow-plugins": {
            "my-custom/file-downloading-plugin": true
        }
    }
}
```

The plugin method is preferable when user interaction is wanted or adhering to Composer commandline arguments (like verbose output etc) is required. Plugins can listen and subscribe to the various events Composer uses and be triggered by install or update commands. They can [define their own commands](https://getcomposer.org/doc/articles/plugins.md#command-provider) that then might be used via `composer my-plugin-command` in the CLI. Those commands are based on [Symfony Console Component](https://symfony.com/doc/current/components/console.html) capabilities.

## Helpful Links

- [Composer Docs about repositories and packages](https://getcomposer.org/doc/05-repositories.md)
- [Composer Docs about Command Events](https://getcomposer.org/doc/articles/scripts.md#command-events)
- [Composer JSON Schema](https://github.com/composer/composer/blob/main/res/composer-schema.json)
- [Subresource Integrity Hash Generator](https://www.srihash.org)
- [SHA1 sum of package dists should be more reliable than a SHA1 on the zip result](https://github.com/composer/composer/issues/2540)
