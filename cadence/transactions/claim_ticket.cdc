import Melody from 0xMelody
import NonFungibleToken from 0xNonFungibleToken

transaction(id: UInt64) {
  var userCertificateCap: Capability<&{Melody.IdentityCertificate}>
  var receiverCollection: &{NonFungibleToken.Receiver}
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

    if signer.borrow<MelodyTicket.Collection>(from: MelodyTicket.CollectionStoragePath) == nil {

      signer.save(<- MelodyTicket.createEmptyCollection(), to: MelodyTicket.CollectionStoragePath)

      // create a public capability for the collection
      signer.link<&MelodyTicket.Collection{NonFungibleToken.CollectionPublic, MelodyTicket.CollectionPublic, MetadataViews.ResolverCollection}>(
        MelodyTicket.CollectionPublicPath,
        target: MelodyTicket.CollectionStoragePath
      )
      signer.link<&MelodyTicket.Collection{MelodyTicket.CollectionPrivate}>(
        self.CollectionPrivatePath,
        target: self.CollectionStoragePath
      )
    } 

    let receiver = self.userCertificateCap.owner!.address
    let receiverCollectionCap = getAccount(receiver).getCapability<&{NonFungibleToken.Receiver}>(MelodyTicket.CollectionPublicPath)
    self.receiverCollection = receiverCollectionCap.borrow()?? panic("Canot borrow receiver's collection")

  }
  execute {
     self.receiverCollection.deposit(token: <- Melody.claimTicket(userCertificateCap: self.userCertificateCap, paymentId: id))
  }
}
