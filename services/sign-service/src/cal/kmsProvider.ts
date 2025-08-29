import { KMSClient, GetPublicKeyCommand, SignCommand } from "@aws-sdk/client-kms";
import { createHash } from "crypto";

export class KMSProvider {
  private client: KMSClient;
  constructor(region: string) {
    // Use VPC endpoint to avoid public internet timeouts in NAT-less architecture
    const endpoint = process.env.AWS_ENDPOINT_URL_KMS || 
      `https://vpce-0b485558f2c45e37b.kms.${region}.vpce.amazonaws.com`;
    
    this.client = new KMSClient({ 
      region,
      endpoint 
    });
  }

  async signDigest(params: { keyRef: string, digestHex: string }): Promise<{ derHex: string, kid: string, requestId: string }> {
    const digest = Buffer.from(params.digestHex, 'hex');

    const sign = await this.client.send(new SignCommand({
      KeyId: params.keyRef, // alias or ARN
      Message: digest,
      MessageType: "DIGEST",
      SigningAlgorithm: "ECDSA_SHA_256"
    }));

    const reqId = sign?.$metadata?.requestId || '';
    const der = sign.Signature!;
    const derHex = Buffer.from(der).toString('hex');

    // Derive a kid from the public key thumbprint
    const pub = await this.client.send(new GetPublicKeyCommand({ KeyId: params.keyRef }));
    const spki = Buffer.from(pub.PublicKey!);
    // Simple thumbprint: sha256(SPKI DER)
    const kid = createHash('sha256').update(spki).digest('hex').slice(0, 16);

    return { derHex, kid, requestId: reqId };
  }
}
