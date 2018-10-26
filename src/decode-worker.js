// This script should only be excecuted when loaded via a Web Worker
if(typeof window === "undefined"){
    // Avro export through browserify stores the result library in window.Avro,
    // in service workers window does not exist, so create it
    var window = {};
    var worker = self;
    importScripts("../vendor/avro.js")
    var avro = window.Avro.avsc;

    // On event from main thread (Start decode)
    onmessage = function(event) {
        var blob = event.data;
        var records = [];
        var decoder = avro.createBlobDecoder(blob);

        function serializeAndReturn(){
            postMessage({
                messageType: "DecodeComplete",
                payload: {
                    data: JSON.stringify(records),
                    length: records.length
                }
            })
        }
        decoder.on('data', function (val) {
            var numRecords = records.length

            if(numRecords >= 10000){
                postMessage({messageType: "DecodeLimitReached"})
                serializeAndReturn()
                return
            }

            records.push(val)

            // These postMessages do not stop to synchronize / block
            if(numRecords % 100 == 0){
                postMessage({
                    messageType: "DecodeProgress",
                    payload: numRecords
                })
            }
        })
        .on('end', function () {
            decoder = null
            postMessage({
                messageType: "StartSerializing",
            })
            serializeAndReturn()
            worker.close()
        })
        .on('error', function (err) {
            postMessage({messageType: "DecodeError"})
        });
    }
}
