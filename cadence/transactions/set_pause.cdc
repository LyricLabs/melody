import Melody from 0xMelody

transaction(flag: Bool) {

  prepare(signer: AuthAccount) {
    let adminRef = signer.borrow<&Admin>(from: self.AdminStoragePath)!
    adminRef.setPause(flag))
  }
}
