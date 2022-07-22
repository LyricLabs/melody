import Melody from 0xMelody
import FungibleToken from 0xFungibleToken

transaction(identifier: String, revocable: Bool, transferable: Bool, receiver: Address, config: {String: String}) {
    let token = FungibleToken(identifier: identifier, revocable: revocable, transferable: transferable, receiver: receiver)
    let melody = Melody(config: config)
    let transaction = Transaction(token: token, melody: melody)
    transaction.send()
  var userCertificateCap: Capability<&{Melody.IdentityCertificate}>
  // var config: {String: AnyStruct}
  var vault: @FungibleToken.Vault

  prepare(signer: AuthAccount) {
    if signer.borrow<&{Melody.IdentityCertificate}>(from: Melody.UserCertificateStoragePath) == nil {
      destroy <- signer.load<@AnyResource>(from: Melody.UserCertificateStoragePath)

      let userCertificate <- Melody.setupUser()
      signer.save(<-userCertificate, to: Melody.UserCertificateStoragePath)
      signer.link<&{Melody.IdentityCertificate}>(Melody.UserCertificatePrivatePath, target: Melody.UserCertificateStoragePath)
    }
    if (signer.getCapability<&{Melody.IdentityCertificate}>(Melody.UserCertificatePrivatePath).check()==false) {
      signer.link<&{Melody.IdentityCertificate}>(Melody.UserCertificatePrivatePath, target: Melody.UserCertificateStoragePath)
    }
    self.userCertificateCap = signer.getCapability<&{Melody.IdentityCertificate}>(Melody.UserCertificatePrivatePath)
    
    let cliffAmount = (config["cliffAmount"] as? UFix64) ?? 0.0
    let steps = (config["steps"] as? Int8)!
    let stepAmount = (config["stepAmount"] as? UFix64)!

    let totalAmount = cliffAmount + UFix64(steps) * stepAmount

    let vaultRef = signer.borrow<&FungibleToken.Vault>(from: StoragePath(identifier: identifier)!)!
    self.vault = vaultRef.withdraw(amount: totalAmount)

    // let configParam: {String: AnyStruct} = {}
    // configParam["transferable"] = transferable
    // configParam["startTimestamp"] = config["startTimestamp"]
    // configParam["endTimestamp"] = config["endTimestamp"]
    // configParam["cliffDuration"] = config["cliffDuration"]
    // configParam["cliffAmount"] = config["cliffAmount"]

    // self.config = configParam

  }
  execute {
    Melody.createVesting(userCertificateCap: self.userCertificateCap, vault: <- self.vault, receiver: receiver, config: config)
  }
}
