import Melody from 0xMelody

transaction(commision: UFix64) {

  prepare(signer: AuthAccount) {
    let adminRef = signer.borrow<&Admin>(from: self.AdminStoragePath)!
    adminRef.setCommision(commision)
  }
}
