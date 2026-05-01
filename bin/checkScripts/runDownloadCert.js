// runDownloadCert.js
// Script to run the certificate download and handle backups
const fs = require('fs');
const path = require('path');
const downloadCert = require('./downloadCert');

/**
 * Absolute path where the downloaded certificate will be stored.
 * Resolves to `download_ca_cert.pem` in the same directory as this script.
 *
 * @type {string}
 */
const OUTPUT_FILE = path.resolve(__dirname, 'download_ca_cert.pem');

/**
 * Entry point: backs up any pre-existing certificate file, then fetches the
 * current TLS certificate from github.com on port 443 and saves it to
 * {@link OUTPUT_FILE}.
 *
 * Backup naming convention: `<OUTPUT_FILE>.<unix-timestamp-ms>.bak`
 *
 * Exits with code 1 if the download or file operations fail so that CI
 * pipelines can detect and surface the error.
 *
 * @async
 * @returns {Promise<void>}
 */
(async () => {
    try {
        // Backup existing certs
        if (fs.existsSync(OUTPUT_FILE)) {
            const backupFile = `${OUTPUT_FILE}.${Date.now()}.bak`;
            fs.renameSync(OUTPUT_FILE, backupFile);
            console.log(`Existing certificate backed up as ${backupFile}`);
        }

        // Download from github.com
        await downloadCert('github.com', 443, OUTPUT_FILE);
        console.log(`Certificate successfully saved to ${OUTPUT_FILE}`);
    } catch (err) {
        console.error('Error downloading certificate:', err);
        process.exit(1); // Fail workflow if download fails
    }
})();
