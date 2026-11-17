import json, os, time, boto3

# ElasticMQ local por padrão. Para usar o Amazon SQS de verdade (Caminho B),
# rode com SQS_ENDPOINT="" e configure as credenciais com "aws configure".
ENDPOINT = os.environ.get("SQS_ENDPOINT", "http://localhost:9324")
FILA = os.environ.get("SQS_FILA", "guias")

if ENDPOINT:
    sqs = boto3.client(
        "sqs", endpoint_url=ENDPOINT, region_name="us-east-1",
        aws_access_key_id="x", aws_secret_access_key="x")
else:
    sqs = boto3.client("sqs")

url = sqs.get_queue_url(QueueName=FILA)["QueueUrl"]
print("consumidor PID", os.getpid(), "lendo", url)


def agora():
    return time.strftime("%H:%M:%S")


def processar(pedido):
    if "requisicaoId" not in pedido:
        raise ValueError("mensagem sem requisicaoId")
    print(agora(), os.getpid(), "guia G-" + pedido["requisicaoId"],
          pedido.get("hospital"))


while True:
    resp = sqs.receive_message(
        QueueUrl=url, MaxNumberOfMessages=10, WaitTimeSeconds=10,
        MessageSystemAttributeNames=["ApproximateReceiveCount"])

    for m in resp.get("Messages", []):
        try:
            processar(json.loads(m["Body"]))
            # só apaga (confirma) depois de processar com sucesso
            sqs.delete_message(QueueUrl=url, ReceiptHandle=m["ReceiptHandle"])
        except Exception as e:
            # não apaga: a mensagem volta a ficar visível depois do visibility timeout
            print(agora(), "falhou; volta para a fila:", e, m.get("Attributes"))
