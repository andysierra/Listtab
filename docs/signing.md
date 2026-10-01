# Stable code signature (keeps the Accessibility permission across rebuilds)

Create a self-signed code-signing certificate once; `build.sh` uses it automatically when its name is
`ListTab Local Signing`.

```bash
cat > cs.cnf <<'CNF'
[req]
distinguished_name=dn
x509_extensions=ext
prompt=no
[dn]
CN=ListTab Local Signing
[ext]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
CNF
openssl req -x509 -newkey rsa:2048 -nodes -keyout k.pem -out c.pem -days 3650 -config cs.cnf
openssl pkcs12 -export -inkey k.pem -in c.pem -out c.p12 -passout pass:listtab
security import c.p12 -k ~/Library/Keychains/login.keychain-db -P listtab -T /usr/bin/codesign
rm k.pem c.p12 cs.cnf
```

Then rebuild. If ListTab shows up twice in *Accessibility*, or the permission looks on but the app doesn't react:

```bash
tccutil reset Accessibility com.andysierra.listtab
```

and grant it again.
