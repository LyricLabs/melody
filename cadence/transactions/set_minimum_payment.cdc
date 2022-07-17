import Melody from 0xMelody

transaction(min: UFix64) {

  prepare(signer: AuthAccount) {
    let adminRef = signer.borrow<&Admin>(from: self.AdminStoragePath)!
    adminRef.setMinimumPayment(min)
  }
}
