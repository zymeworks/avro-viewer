(function (global){
    'use strict';

    /**
     * Load contents of the first file selected from a HTMLInputElement
     * as text
     *
     * @param  {InputElement}   input   DOM element <input[type=file]>
     * @param  {Function}       cb      Result callback, nodejs style (err, data)
     */
    function fileLoader(input, cb) {
      if (!input || (input.type !== 'file')) {
        cb({'message': 'fileLoader: You must provide an element <input type=file>'})
        return
      } else if (input.files.length === 0) {
        cb({'message': 'fileLoader: no file was selected'})
        return
      }

      // only loads the first file
      var file = input.files[0];
      var reader = new FileReader();

      reader.onerror = (function(event) {
        var msg = fileReaderErrorCode(event);
        if (msg) {
          cb({'message': msg});
        }
      });

      reader.onload = (function(event) {
        var text = event.target.result;
        cb(null, {
          contents: text,
          filename: file.name
        });
      });

      reader.readAsText(file);
    }

    function fileReaderErrorCode(evt) {
      switch(evt.target.error.code) {
      case evt.target.error.NOT_FOUND_ERR:
        return 'File Not Found!';
      case evt.target.error.NOT_READABLE_ERR:
        return 'File is not readable';
      case evt.target.error.ABORT_ERR:
        return '';
      default:
        return 'An error occurred reading this file.';
      }
    }

    global.fileLoader = fileLoader;
  }(window))