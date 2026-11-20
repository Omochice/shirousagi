///|
test "an executable the keychain no longer trusts is told how to recover" {
  inspect(
    refusal(-25308, Some("https://t.example.com")),
    content="the keychain did not let this shirousagi executable read the password for https://t.example.com, which happens after shirousagi is rebuilt or upgraded; run `shirousagi logout --endpoint https://t.example.com` and then `shirousagi login --endpoint https://t.example.com --username <name>`",
  )
}

///|
test "the recovery hint without a known account stays generic" {
  inspect(
    refusal(-25308, None),
    content="the keychain did not let this shirousagi executable read the stored passwords, which happens after shirousagi is rebuilt or upgraded; run `shirousagi logout --endpoint <endpoint>` and then `shirousagi login --endpoint <endpoint> --username <name>`",
  )
}

///|
test "a failure inside the keyring module is not reported as a store code" {
  inspect(
    refusal(@keyring.INTERNAL, Some("https://t.example.com")),
    content="the credential store could not be used; the keyring module itself failed, not the store",
  )
}

///|
test "other refusal codes keep the plain message" {
  inspect(
    refusal(-25293, Some("https://t.example.com")),
    content="the credential store refused the operation (code -25293)",
  )
}
