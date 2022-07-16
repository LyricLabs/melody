import Melody from 0xMelody

transaction(duration: UFix64) {

  prepare(signer: AuthAccount) {
    let adminRef = signer.borrow<&Admin>(from: self.AdminStoragePath)!
    adminRef.setGraceDuration(duration)
  }
}
