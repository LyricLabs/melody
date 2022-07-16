import Melody from 0xMelody
import MelodyTicket from 0xMelodyTicket

transaction(userCertificateCap: Capability<&{Melody.IdentityCertificate}>, paymentId: UInt64, identifier: String) {
  var userCertificateCap: Capability<&{Melody.IdentityCertificate}>
  var ticketRef: &MelodyTicket.NFT
  var receiver: &{FungibleToken.Receiver}

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
    
    let collectionPriv =  signer.borrow<&MelodyTicket.CollectionPrivate>(from: Melody.CollectionStoragePath)!
    self.ticketRef = collectionPriv.borrowMelodyTicket(id: paymentId)!
    
    self.receiver = signer.getCapability(PublicPath(identifier: identifier)!).borrow<&{FungibleToken.Receiver}>()
  }
  execute {
    self.receiver.deposit(from: <- Melody.withdraw(userCertificateCap: self.userCertificateCap, ticket: self.ticketRef))
  }
}
