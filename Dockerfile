FROM alpine/curl:3.14 as DOWNLOADS

RUN mkdir -p /groundingdino \
    && cd /groundingdino \
    && curl -sLO https://github.com/IDEA-Research/GroundingDINO/releases/download/v0.1.0-alpha/groundingdino_swint_ogc.pth \
    && curl -sLO https://raw.githubusercontent.com/IDEA-Research/GroundingDINO/main/groundingdino/config/GroundingDINO_SwinT_OGC.py

ENV BERT_BASE_UNCASED_COMMIT_SHA=26c976dcb042f61e05f27fe2d9836a2c5237bfb3
RUN mkdir -p /bert-base-uncased \
    && cd /bert-base-uncased \
    && curl -sLO https://huggingface.co/bert-base-uncased/raw/${BERT_BASE_UNCASED_COMMIT_SHA}/config.json \
    && curl -sLO https://huggingface.co/bert-base-uncased/raw/${BERT_BASE_UNCASED_COMMIT_SHA}/pytorch_model.bin \
    && curl -sLO https://huggingface.co/bert-base-uncased/raw/${BERT_BASE_UNCASED_COMMIT_SHA}/tokenizer_config.json \
    && curl -sLO https://huggingface.co/bert-base-uncased/raw/${BERT_BASE_UNCASED_COMMIT_SHA}/tokenizer.json \
    && curl -sLO https://huggingface.co/bert-base-uncased/raw/${BERT_BASE_UNCASED_COMMIT_SHA}/vocab.txt


FROM pytorch/torchserve:0.8.0-cpu as MAR_BUILDER

COPY --from=DOWNLOADS /groundingdino /home/model-server/tmp/weights
COPY --from=DOWNLOADS /bert-base-uncased /home/model-server/tmp/bert-base-uncased
COPY grounding_dino_handler.py /home/model-server/tmp/

RUN cd /home/model-server/tmp \
    && torch-model-archiver \
       --model-name groundingdino \
       --version 0.1.0-alpha \
       --serialized-file weights/groundingdino_swint_ogc.pth \
       --handler grounding_dino_handler.py \
       --extra-files weights/GroundingDINO_SwinT_OGC.py,bert-base-uncased/*


FROM bitnami/git:2.41.0-debian-11-r2 as GIT
RUN git clone https://github.com/IDEA-Research/GroundingDINO.git /tmp/GroundingDINO


FROM pytorch/torchserve:0.8.0-gpu

COPY --from=MAR_BUILDER /home/model-server/tmp/groundingdino.mar /home/model-server/model-store/groundingdino.mar
COPY config.properties /home/model-server/config.properties
COPY --from=GIT /tmp/GroundingDINO /usr/src/GroundingDINO

