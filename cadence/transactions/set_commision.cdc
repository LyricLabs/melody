import Melody from 0xMelody

transaction(commission: UFix64) {

  prepare(signer: AuthAccount) {
    let adminRef = signer.borrow<&Admin>(from: self.AdminStoragePath)!
    adminRef.setCommission(commission)
  }
}
