const http = require("http");
const fs = require("fs").promises;

const host = 'localhost';
const port = 8080;

let indexFile;
let ethers;

const requestListener = function (req, res) {
    if (req.url.endsWith('.html')) {
        res.setHeader("Content-Type", "text/html");
        res.writeHead(200);
        res.end(indexFile);
    } else if (req.url.endsWith('.js')) {
        res.setHeader("Content-Type", "application/javascript");
        res.writeHead(200);
        res.end(ethers);
    }
};

const server = http.createServer(requestListener);

fs.readFile(__dirname + "/index.html")
    .then(contents => {
        indexFile = contents;

        fs.readFile(__dirname + "/ethers.js")
            .then(contents2 => {
                ethers = contents2;

                server.listen(port, host, () => {
                    console.log(`Server is running on http://${host}:${port}`);
                });
            })
            .catch(err2 => {
                console.error("could not read ethers");
                process.exit(1);
            });
    })
    .catch(err => {
        console.error(`Could not read index.html file: ${err}`);
        process.exit(1);
    });