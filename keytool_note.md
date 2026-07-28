# keytool note

## options: genkey

```bash
keytool -genkey -noprompt -trustcacerts
  -keyalg RSA
  -alias ${cert.alias}
  -dname  ${dn.name}
  -keypass ${key.pass}
  -keystore ${keystore.file}
  -storepass ${keystore.pass}
```

```bash
keytool -genkey
  -alias keyAlias
  -keyalg RSA
  -keypass changeit
  -storepass changeit
  -keystore keystore.jks
```

## options: list

```bash
keytool -list -v
  -keystore ${keystore.file}
  -storepass ${keystore.pass}
```

```bash
keytool -list -v
  -alias ${cert.alias}
  -keystore ${keystore.file}
  -storepass ${keystore.pass}
```

## options: export

```bash
keytool -export
  -alias keyAlias
  -keystore keystore.jks
  -storepass changeit
  -file server.cer
```

## options: import

```bash
keytool -import -v -trustcacerts
  -file server.cer
  -alias keyAlias
  -keystore cacerts.jks
  -keypass changeit
```

```bash
keytool -import -v -trustcacerts
  -file server.cer
  -alias keyAlias
  -keypass changeit
  -keystore cacerts.jks
  -storepass changeit
```

## options: delete

```bash
keytool -delete -noprompt
  -alias ${cert.alias}
  -keystore ${keystore.file}
  -storepass ${keystore.pass}
```
