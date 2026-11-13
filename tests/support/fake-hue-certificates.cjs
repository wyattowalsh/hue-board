"use strict";

const { X509Certificate } = require("node:crypto");
const { chmod, mkdtemp, readFile, rm, writeFile } = require("node:fs/promises");
const { tmpdir } = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

function normalizeBridgeID(value) {
  const bridgeID = String(value ?? "").replace(/[:-]/g, "").toLowerCase();
  if (!/^[a-f\d]{16}$/.test(bridgeID)) {
    throw new TypeError("bridgeID must contain exactly 16 hexadecimal characters");
  }
  return bridgeID;
}

function normalizeSHA256(value) {
  const fingerprint = String(value ?? "").replace(/:/g, "").toLowerCase();
  if (!/^[a-f\d]{64}$/.test(fingerprint)) {
    throw new TypeError("certificate fingerprint must contain exactly 64 hexadecimal characters");
  }
  return fingerprint;
}

function hasOpenSSL() {
  const result = spawnSync("openssl", ["version"], { encoding: "utf8" });
  return result.status === 0;
}

async function generateFakeHueCertificate({
  bridgeID = "001788fffe123456",
  directory = null,
  days = 3650,
} = {}) {
  const normalizedBridgeID = normalizeBridgeID(bridgeID);
  if (!Number.isSafeInteger(days) || days < 1) {
    throw new TypeError("days must be a positive safe integer");
  }
  if (!hasOpenSSL()) {
    throw new Error("OpenSSL is required to generate fake Hue certificates");
  }

  const ownsDirectory = directory == null;
  const outputDirectory = directory
    ? path.resolve(directory)
    : await mkdtemp(path.join(tmpdir(), "hue-board-fake-tls-"));
  const keyPath = path.join(outputDirectory, "bridge-key.pem");
  const certificatePath = path.join(outputDirectory, "bridge-cert.pem");
  const configPath = path.join(outputDirectory, "openssl.cnf");
  const config = [
    "[req]",
    "prompt = no",
    "distinguished_name = distinguished_name",
    "x509_extensions = extensions",
    "[distinguished_name]",
    `CN = ${normalizedBridgeID}`,
    "[extensions]",
    "basicConstraints = critical,CA:FALSE",
    "keyUsage = critical,digitalSignature,keyEncipherment",
    "extendedKeyUsage = serverAuth",
    `subjectAltName = DNS:${normalizedBridgeID}`,
    "subjectKeyIdentifier = hash",
    "authorityKeyIdentifier = keyid,issuer",
    "",
  ].join("\n");
  await writeFile(configPath, config, { mode: 0o600 });

  const result = spawnSync(
    "openssl",
    [
      "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-sha256",
      "-days", String(days), "-config", configPath, "-extensions", "extensions",
      "-keyout", keyPath, "-out", certificatePath,
    ],
    { encoding: "utf8" },
  );
  if (result.status !== 0) {
    if (ownsDirectory) await rm(outputDirectory, { recursive: true, force: true });
    throw new Error(`OpenSSL certificate generation failed: ${result.stderr || result.stdout}`);
  }
  await chmod(keyPath, 0o600);
  await chmod(certificatePath, 0o600);

  const [key, cert] = await Promise.all([
    readFile(keyPath, "utf8"),
    readFile(certificatePath, "utf8"),
  ]);
  const parsed = new X509Certificate(cert);
  const sha256 = normalizeSHA256(parsed.fingerprint256);
  if (!parsed.subject.split(/\s*,\s*|\n/).includes(`CN=${normalizedBridgeID}`)) {
    throw new Error("Generated certificate subject does not match the Hue Bridge ID");
  }

  return {
    bridgeID: normalizedBridgeID,
    cert,
    key,
    sha256,
    subject: parsed.subject,
    subjectAltName: parsed.subjectAltName,
    keyPath,
    certificatePath,
    directory: outputDirectory,
    async cleanup() {
      if (ownsDirectory) await rm(outputDirectory, { recursive: true, force: true });
    },
  };
}

module.exports = {
  generateFakeHueCertificate,
  hasOpenSSL,
  normalizeBridgeID,
  normalizeSHA256,
};
