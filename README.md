## Avro Viewer

Avro Viewer is an [Apache Avro] file explorer built with Elm.

## Demo

View the online demo [here][demo]. This is possible as all the decoding and processing occurs client-side.


## Features

- Drag and Drop
- Recognition of tabular data
- Tree view
- Panel view
- JSON and CSV export


## Building and Developing

Avro Viewer is built with the following technologies:

- [Elm][elm] 0.18.0
- [avsc] (polyfilled / bundled with [Browserify])
- JavaScript ES6
- NPM

```
npm run setup
npm run build
```

Avro Viewer must be served by a web server to allow javascript service workers to load their source. 
For development, use Node's `http-server`:

```
npm run serve
```


## Resources

- [Elm Guide][elm-guide]
- [Elm Ports][elm-ports]


## Screenshots

![File Select](/screenshots/file.png?raw=true "File Select")

![Tree View Complex Structure](/screenshots/tree.png?raw=true "Tree View")


## License

Avro Viewer is licensed under the [MIT License][license].


[Apache Avro]: https://avro.apache.org/docs/current/
[Browserify]: https://browserify.org
[avsc]: https://github.com/mtth/avsc
[demo]: https://zymeworks.github.io/avro-viewer/
[elm]: https://elm-lang.org
[elm-guide]: https://guide.elm-lang.org
[elm-ports]: https://hackernoon.com/how-elm-ports-work-with-a-picture-just-one-25144ba43cdd
[license]: https://raw.github.com/zymeworks/avro-viewer/master/LICENSE
