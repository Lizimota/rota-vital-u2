"""Opcional: recria a fila "guias" com uma DLQ (fila de mensagens mortas).

Depois de 3 recebimentos sem confirmação (maxReceiveCount=3), a mensagem
inválida sai da fila "guias" e vai para "guias-dlq".

Uso (com o ElasticMQ no ar):
    python criar_filas_com_dlq.py
    python consumidor.py        # em outro terminal
    python produtor.py
    python ver_dlq.py           # depois de ~45 s
"""
import json, boto3

sqs = boto3.client(
    "sqs", endpoint_url="http://localhost:9324", region_name="us-east-1",
    aws_access_key_id="x", aws_secret_access_key="x")

# apaga a fila antiga, se existir, para recriar com a política de redrive
try:
    sqs.delete_queue(QueueUrl=sqs.get_queue_url(QueueName="guias")["QueueUrl"])
except sqs.exceptions.QueueDoesNotExist:
    pass

dlq_url = sqs.create_queue(QueueName="guias-dlq")["QueueUrl"]
dlq_arn = sqs.get_queue_attributes(
    QueueUrl=dlq_url, AttributeNames=["QueueArn"])["Attributes"]["QueueArn"]

url = sqs.create_queue(
    QueueName="guias",
    Attributes={
        "VisibilityTimeout": "15",
        "RedrivePolicy": json.dumps(
            {"deadLetterTargetArn": dlq_arn, "maxReceiveCount": "3"}),
    })["QueueUrl"]

print("fila principal:", url)
print("DLQ:", dlq_url, dlq_arn)
print(sqs.get_queue_attributes(QueueUrl=url, AttributeNames=["All"])["Attributes"])
