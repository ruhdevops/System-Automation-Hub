// downloadCert.js
// Function to download a TLS certificate from a host and save to a file
const fs = require('fs');
const tls = require('tls');
const net = require('net');

/**
 * Downloads the TLS certificate from a remote host and saves it as a PEM-encoded
 * file. Establishes a TLS connection, extracts the peer certificate, encodes it
 * in Base64 PEM format, and writes it synchronously to the specified output path.
 *
 * @async
 * @param {string} host       - The hostname to connect to (e.g. "github.com").
 * @param {number} [port=443] - The TCP port to connect on. Defaults to 443 (HTTPS).
 * @param {string} outputFile - Absolute or relative file path where the PEM
 *                              certificate will be written.
 * @returns {Promise<void>} Resolves when the certificate has been written
 *                          successfully; rejects with an Error on connection
 *                          failure or if no certificate is returned.
 *
 * @example
 * const downloadCert = require('./downloadCert');
 * await downloadCert('github.com', 443, './certs/github.pem');
 */
async function downloadCert(host, port = 443, outputFile) {
    return new Promise((resolve, reject) => {
        const socket = tls.connect(port, host, {}, () => {
            const cert = socket.getPeerCertificate();
            if (!cert || !cert.raw) {
                return reject(new Error('Unable to retrieve certificate.'));
            }
            // Save PEM encoded certificate
            const pem = `-----BEGIN CERTIFICATE-----\n${cert.raw.toString('base64')}\n-----END CERTIFICATE-----\n`;
            fs.writeFileSync(outputFile, pem);
            socket.end();
            resolve();
        });

        socket.on('error', (err) => reject(err));
    });
}

// Export function
module.exports = downloadCert;
