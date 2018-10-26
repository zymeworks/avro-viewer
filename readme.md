## Avro Viewer:

### Decode and browse Avro file contents within the browser

Avro Viewer is an Avro/json file explorer built with Elm. It works exclusively within a browser, decoding and parsing [.avro binary files](https://avro.apache.org/docs/current/).

These files can be explored as tables, trees, or panels and exported as JSON or CSV. The viewer supports drag and drop decoding of multiple files at once, including JSON files.

## Demo:
Since all of the decoding work happens in the browser, there is an [online static demo here](https://pages.github.io)!

## Running Locally Quick start:

```
npm run setup

npm run serve
```

Setup will cover installing the packages, building the source, and copying the build files. Serve will use node http-server to serve the build files from the local file system. This is needed because the service worker js files are loaded dynamically.

## Building and Developing:

The project stack is as follows:

- [Elm](http://elm-lang.org/) 0.18.0
- [avsc](https://github.com/mtth/avsc) (polyfilled / bundled with [Browserify](http://browserify.org/))
- JavaScript ES6
- NPM

Decoding work happens in vanilla JS and the visualizations are handled with the Elm program.

To make changes, run a one time

​```npm run setup```

and as you develop run

```npm run build```

## Resources:

Work on the visualization features is done through the Elm program. Changes will require unerstanding of the Elm language and architecture, which you read about [here](https://guide.elm-lang.org/). (note that Avro Viewer is reliant on Elm 0.18)

About ports, getting started with development

The app utilizes Elm ports to pass the result parsed file data in order to visualize, read about ports [here](https://hackernoon.com/how-elm-ports-work-with-a-picture-just-one-25144ba43cdd).

Parsing hapens in vanilla JS with avsc through 'main.js' which loads the service worker 'decode-worker.js'. Results are stringified and passed to Elm, which in turn decodes and wraps the JSON objects with container types which allows us to add features such as paging, collapsing, etc.

## Features:

#### Drag and Drop multiple files to decode
- Utilizes multi threading decoding work with service workers, a new worker will spawn for each file


#### Recognizes tabular data
- If the schema of all objects in an array are flat (Only primitive types) the array can (and will be) be shown as a table
- Paging for tables, performemt with ten thousand records
- Tabular data can be exported or copy pasted easily into programs like Excel


#### Tree view:
- With Tree view you can expore complex data with lots of nested properties.
- Collapse and expand through lots of nested data
- Tree view will render tables within properties where applicable
- You can collapse, expand, and page data within array elements


#### Panel view:
- With Panel view, scoped sections of the model are split into different panels
- This makes it easy to find and focus only on the data that you might care about.


#### Exporting to JSON and CSV
- ​Also provides functionality to convert avro to json and csv
- Once the data is read in and parsed, you can save/export the data in two ways
    - Save as JSON (In tree view): Find the file container container the data you want, click the Download JSON button.
    - Export as CSV (In panel view or on table): Click the Download CSV button on the top left of any table


## Screenshots

![File Select](/../master/screenshots/file.png?raw=true "File Select")

![Tree View Complex Structure](/../master/screenshots/tree.png?raw=true "Tree View Complex Structure")
