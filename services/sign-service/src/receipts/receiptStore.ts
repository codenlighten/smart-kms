import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));

export async function putReceipt(table: string, pk: string, sk: string, receipt: any) {
  await ddb.send(new PutCommand({
    TableName: table,
    Item: {
      pk, sk,
      schemaVersion: receipt.schemaVersion,
      policyVersion: receipt.policyVersion,
      subject: receipt.subject,
      inputs: receipt.inputs,
      sig: receipt.sig,
      attest: receipt.attest || {},
      anchors: receipt.anchors || {},
      issuedAt: receipt.issuedAt,
      ext: receipt.ext || {}
    },
    ConditionExpression: "attribute_not_exists(pk) AND attribute_not_exists(sk)"
  }));
}

export async function getRecentReceipts(table: string, pk: string, limit: number = 10) {
  const result = await ddb.send(new QueryCommand({
    TableName: table,
    KeyConditionExpression: "pk = :pk",
    ExpressionAttributeValues: {
      ":pk": pk
    },
    ScanIndexForward: false, // Sort by SK descending (newest first)
    Limit: limit
  }));

  return result.Items || [];
}
