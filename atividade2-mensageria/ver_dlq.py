"""Mostra o que caiu na DLQ (sem apagar)."""
import boto3

sqs = boto3.client(
    "sqs", endpoint_url="http://localhost:9324", region_name="us-east-1",
    aws_access_key_id="x", aws_secret_access_key="x")

url = sqs.get_queue_url(QueueName="guias-dlq")["QueueUrl"]
resp = sqs.receive_message(
    QueueUrl=url, MaxNumberOfMessages=10, WaitTimeSeconds=2,
    VisibilityTimeout=0, MessageSystemAttributeNames=["All"])

msgs = resp.get("Messages", [])
print(len(msgs), "mensagem(ns) na DLQ")
for m in msgs:
    print(m["Body"], m.get("Attributes"))
