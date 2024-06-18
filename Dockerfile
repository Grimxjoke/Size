FROM ubuntu:20.04

RUN set -eux

ENV DEBIAN_FRONTEND=noninteractive 

WORKDIR /root/2024-06-size

RUN echo "Install OS libraries"
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y python3-pip wget curl git

RUN echo "Install solc-select"
RUN pip3 install solc-select

RUN echo "Install solc 0.8.23"
RUN solc-select install 0.8.23
RUN solc-select use 0.8.23

RUN echo "Install echidna"
RUN wget https://github.com/crytic/echidna/releases/download/v2.2.3/echidna-2.2.3-x86_64-linux.tar.gz
RUN tar -xvkf echidna-2.2.3-x86_64-linux.tar.gz
RUN mv echidna /usr/bin/
RUN rm echidna-2.2.3-x86_64-linux.tar.gz
RUN echidna --version

RUN echo "Install Node.js"
ENV NODE_VERSION=18.17.0
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
ENV NVM_DIR=/root/.nvm
RUN . "$NVM_DIR/nvm.sh" && nvm install ${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm use v${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm alias default v${NODE_VERSION}
ENV PATH="$NVM_DIR/versions/node/v${NODE_VERSION}/bin/:${PATH}"
RUN node --version
RUN npm --version
RUN npm install --global yarn
RUN yarn --version

RUN echo "Install foundry"
RUN curl -L https://foundry.paradigm.xyz | bash
RUN mv /root/.foundry/bin/foundryup /usr/bin
RUN foundryup

RUN echo "Install halmos"
RUN pip3 install halmos

RUN echo "Install crytic-compile"
RUN pip3 install crytic-compile

RUN echo "Install slither"
RUN pip3 install slither-analyzer

COPY . .