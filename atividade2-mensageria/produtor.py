import json, os, boto3

ENDPOINT = os.environ.get("SQS_ENDPOINT", "http://localhost:9324")
FILA = os.environ.get("SQS_FILA", "guias")

if ENDPOINT:
    sqs = boto3.client(
        "sqs", endpoint_url=ENDPOINT, region_name="us-east-1",
        aws_access_key_id="x", aws_secret_access_key="x")
else:
    sqs = boto3.client("sqs")

url = sqs.get_queue_url(QueueName=FILA)["QueueUrl"]

# 20 pedidos válidos
for i in range(1, 21):
    pedido = {"requisicaoId": f"R-{i:03d}", "hospital": "H-Recife"}
    sqs.send_message(QueueUrl=url, MessageBody=json.dumps(pedido))

# 1 pedido inválido (sem requisicaoId): vai falhar no consumidor e voltar para a fila
sqs.send_message(QueueUrl=url, MessageBody=json.dumps({"hospital": "H-Recife"}))

print("21 mensagens enviadas")
