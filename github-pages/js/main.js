(function(global){
    var app = Elm.Main.fullscreen();

    //File loaders and ports for file event
    if (!(fileLoader instanceof Function)) {
        throw new Error('Failed to import fileLoader Function')
    }
    if (!(saveAs instanceof Function)) {
        throw new Error('Failed to import saveAs Function')
    }

    // To avoid sending potentially huge amounts of data to and from Elm,
    // in order to support the save as JSON feature, we can just hold on to
    // the result that was originally passed to elm. Since file save happens through a port anyways
    var fileResults = [];

    // Push callbacks from ELM
    // =======================

    // When the user clicks "select files" input, dispatched from Elm
    app.ports.fileSelected.subscribe(function (id) {
        var node = document.getElementById(id);
        if (node !== null && node.type === "file") {
            decodeAndSendFiles(node.files);
        }
    })

    // When the user clicks the "Download as" button, dispatched from Elm
    /*  Two cases, JSON or CSV. CSV data is parsed and handled by Elm, so just
        pass that through. JSON can be huge and is stored here as jsonResult,
        so just lookup by index provided by Elm */
    app.ports.fileSave.subscribe(function (payload) {
        var encoding;
        switch(payload.filetype){
            case 'json':
                var parsedJson = JSON.parse(fileResults[payload.index].rawJson)     // de-stringify
                var prettyJson = JSON.stringify(parsedJson, null, 2);
                payload.contents = prettyJson;
                encoding = 'application/json;charset=utf-8';
                break;
            case 'csv':
                encoding = 'application/plain;charset=utf-8';
                break;
        }
        if(!encoding){
            throw 'Unhandled format for save as';
        }
        // Create and save blob
        var blob = new Blob([payload.contents], { type: encoding });
        var filename = payload.filename.split('.')[0];
        filename += '.' + payload.filetype;
        saveAs(blob, filename);
    });

    // When the user selects and opens a new panel, scroll container all the way to right
    function scrollCompletelyRight(id) {
        var node = document.getElementById(id);
        if (node != null) {
            node.scrollLeft = node.scrollWidth;
        }
    }
    app.ports.scrollPanelViewRight.subscribe(function (id) {
        global.requestAnimationFrame(scrollCompletelyRight.bind(null, id))
    });


    // File read and parse
    // ===================

    function decodeAndSendFiles(files){
        fileResults = [];       // Reset results array

        var promises = []
        for(var i = 0; i < files.length; i++){
            promises.push(readFile(files[i], i));
        }

        // Once all files have fired their callback, send the data back to elm as one bundle
        Promise.all(promises).then(function(results){
            fileResults = results;

            var successfulResults = JSON.stringify(fileResults.filter(function(result){
                return result.status == "Ok";
            }));
            var errorResults = JSON.stringify(fileResults.filter(function(result){
                return result.status == "Failed";
            }));

            app.ports.fileParseResults.send([successfulResults, errorResults]);
        });
    }

    // Parameterize file reference since callback is async
    // returns promise
    // agrs file, index
    function readFile(file, index){
        return new Promise(function(resolve){
            var reader = new FileReader();
            var fileType = "";

            // The app supports both raw JSON and binary Avro,
            // check the file name to see if we even need to decode
            if(file.name.indexOf(".json") != -1){
                fileType = "json"
            }
            else if (file.name.indexOf(".avro") != -1){
                fileType = "avro"
            }
            else{   // It's not json or avro, we can't parse it!
                resolve({
                    status: "Failed",
                    message: "File is not in the .json or .avro format",
                    filename: file.name,
                    index: index
                });
                return;
            }

            // On file read callback
            reader.onload = function() {
                var data = this.result;
                switch(fileType){
                    case "json":
                        validateAndSendJsonFile(file.name, data, resolve, index);
                        break;
                    case "avro":
                        decodeAvroFile(file.name, data, resolve, index);
                        break;
                }
            }

            // Start the read
            if(fileType == "json"){
                reader.readAsText(file);
            }
            else if(fileType == "avro"){
                reader.readAsArrayBuffer(file);
            }
        });
    };

    // This function takes a JSON file object for file name reference, and stringified JSON
    // Verify that the json is valid and send it to Elm in the format expected
    function validateAndSendJsonFile(fname, jsonString, resolve, index){
        // Is this valid json?
        var count;
        try {
            var valid = JSON.parse(jsonString);
            count = (valid && valid.length) || 1;
            if (!(valid && typeof valid === "object")) {
                throw "invalid JSON"
            }
        }
        catch (e) {
            // 'resolving' failed file parsing since Promises.all is all or nothing
            resolve({
                status: "Failed",
                message: "Unable to properly parse JSON contents!",
                filename: fname,
                index: index
            });
            return;
        }

        resolve({
            status: "Ok",
            filename: fname,
            data: jsonString,
            rawJson: jsonString,
            count: count,
            limitReached: false,
            index: index
        });
    }

    // This function takes an AVRO file object for file name reference, and raw bytes
    // Initializes avro decoder and attempts to parse concurrently, passing
    // the results back to elm as they are recieved
    function decodeAvroFile(fname, rawData, resolve, index){
        var blob = new Blob([new Uint8Array(rawData)]);
        var decodeWorker = new Worker('/avro-viewer/github-pages/js/decode-worker.js');

        var limitReached = false;
        decodeWorker.onmessage = function(e){
            // Our Worker can return various types of messages
            switch(e.data.messageType){
                case "DecodeProgress":
                    // Progress call back for decode feedback
                    app.ports.fileDecodeProgress.send([index, fname, e.data.payload]);
                    break;
                case "StartSerializing":
                    console.log("Finished decoding, start serialization")
                    break;
                case "DecodeComplete":
                    // update decoded records ui feedback
                    app.ports.fileDecodeProgress.send([index, fname, e.data.payload.length]);
                    decodeWorker.terminate();

                    resolve({
                        status: "Ok",
                        filename: fname,
                        data: e.data.payload.data,
                        rawJson: e.data.payload.data,
                        count: e.data.payload.length,
                        limitReached: limitReached,
                        index: index
                    });
                    break;
                case "DecodeLimitReached":
                    limitReached = true;
                    break;
                case "DecodeError":
                    decodeWorker.terminate()
                    resolve({
                        status: "Failed",
                        message: "Unable to properly parse JSON contents!",
                        filename: fname,
                        index: index
                    });
                    break;
            }
        }

        // Provide the worker the binary blob and start decoding
        decodeWorker.postMessage(blob);
    }


    // Dropzone
    /*  There are some limitations with the data we can pass
        through ports, that being limited to primive elm types.
        Since we are dealing with binary data we can not send
        a string, and binary data doesnt work with ports.
        Set up a listener here for when elements are added
        to the DOM, scanning and checking if the file dropzone
        we declared in Elm was added
    */

    // Listener for DOM change with callback
    var observeDOM = (function(){
        var MutationObserver = global.MutationObserver || global.WebKitMutationObserver,
            eventListenerSupported = global.addEventListener;
        return function(obj, callback){
            if( MutationObserver ){
                var obs = new MutationObserver(function(mutations, observer){
                    if( mutations[0].addedNodes.length || mutations[0].removedNodes.length )
                        callback();
                });
                obs.observe( obj, { childList:true, subtree:true });
            }
            else if( eventListenerSupported ){
                obj.addEventListener('DOMNodeInserted', callback, false);
                obj.addEventListener('DOMNodeRemoved', callback, false);
            }
        };
    })();

    // When the view changes, the page state in elm has changed
    // If we can find the dropzone (upload page) set the attribute
    // for Drag and Drop
    observeDOM(document.body, function(){
        var dropzone = document.getElementById("drop-zone");
        if(dropzone != null){
            dropzone.setAttribute('ondrop', 'window.handleDrop(event)')
        }
    });

    global.handleDrop = function(evt){
        evt.preventDefault();
        if(evt && evt.dataTransfer && evt.dataTransfer.files){
            decodeAndSendFiles(evt.dataTransfer.files);
        }
    }

    function getEnv(locationHref){
        if(locationHref.indexOf(".dev") != -1){
            return "nav-bar--development"
        }
        if(locationHref.indexOf(".staging") != -1){
            return "nav-bar--staging"
        }
        return "nav-bar--production"
    }
})(window)
