# 🧪 App de Controle para Bancada Didática de Nível (TCC)
## 📄 Sobre o Projeto
Este repositório contém o código-fonte do aplicativo móvel e do firmware embarcado desenvolvidos como parte de um Trabalho de Conclusão de Curso (TCC) para a Faculdade de Engenharia Mecânica (FEMEC) da Universidade Federal de Uberlândia (UFU).

O objetivo principal deste projeto é permitir o controle remoto e local de uma bancada didática para controle de nível de água, aplicando a teoria de Controle por Realimentação de Estados (State-Space). A solução completa consiste em um aplicativo Flutter para a interface do usuário e um firmware para o microcontrolador ESP32 que gerencia a bancada.

## 🏛️ Arquitetura do Sistema
O sistema foi projetado com uma arquitetura flexível que permite dois modos de operação distintos, utilizando diferentes tecnologias de comunicação:

Frontend (Mobile): Um aplicativo multiplataforma desenvolvido em Flutter, com temas adaptáveis (claro/escuro) e fluxos de usuário distintos para os perfis de Professor e Aluno.

Hardware (Bancada): Um microcontrolador ESP32 é o cérebro da bancada, responsável por ler os sensores, acionar a bomba de água, controlar o feedback visual com LEDs e gerenciar toda a comunicação.

Comunicação Local (Setup): A configuração inicial da bancada (credenciais de Wi-Fi e do servidor MQTT) é feita de forma segura pelo professor através de Bluetooth Low Energy (BLE).

Comunicação Remota (Experimento): Durante o experimento, a troca de dados em tempo real entre o aplicativo do aluno e a bancada é realizada via protocolo MQTT, permitindo o controle e monitoramento à distância.

## ✨ Funcionalidades
### Para o Professor:
Configuração Segura: Conecta-se à bancada via BLE para enviar as credenciais da rede Wi-Fi e do broker MQTT de forma privada.

Monitoramento em Tempo Real: Acessa uma tela de monitoramento que se inscreve dinamicamente nos tópicos do aluno ativo.

Visão Completa: Visualiza tanto os parâmetros de controle enviados pelo aluno quanto os dados de telemetria (nível, tensão, etc.) publicados pela bancada.

## Para o Aluno:
Conexão Remota: Conecta-se à bancada remotamente, informando apenas o endereço do broker MQTT.

Envio de Parâmetros: Insere os ganhos calculados (K, Ke, Nx, Nu) e a referência (ref) para a lei de controle.

Controle do Experimento: Possui comandos para iniciar, pausar e parar a execução do experimento.

Visualização Gráfica: Acompanha o desempenho do sistema através de um gráfico em tempo real que plota o nível da água e a ação de controle (tensão da bomba).

Exportação de Dados: Ao final do experimento, pode salvar todos os dados coletados (tempo, nível, tensão) em um arquivo .txt para análise posterior.

## 🚀 Como Usar
### Fluxo 1: Professor Configura a Bancada
Faça o login como Professor.

Navegue até a tela "Configuração da Bancada".

O aplicativo irá se conectar à bancada via Bluetooth (BLE).

Envie as credenciais da rede Wi-Fi.

Envie as credenciais do Broker MQTT.

A bancada estará online e pronta para receber a conexão de um aluno.

### Fluxo 2: Aluno Executa o Experimento
Faça o login como Aluno.

Navegue até a tela "Configurar Conexões".

Insira o endereço IP do Broker MQTT e conecte-se. O app irá se registrar na bancada.

Navegue até a tela "Parâmetros de Controle".

Insira os valores calculados para os ganhos e a referência desejada.

Clique em "Enviar Parâmetros" para carregar a configuração na bancada.

A tela do experimento será exibida. Utilize os botões para iniciar, pausar e parar o controle.

Após parar o experimento, o botão "Imprimir Resultados" será habilitado para salvar os dados.

## 🔢 Parâmetros de Controle (Valores de Exemplo)
Os seguintes ganhos foram calculados e testados para o modelo da bancada, servindo como um ponto de partida para os experimentos:

### Parâmetro	Descrição	Valor Sugerido
K	Ganho do Regulador de Estados	50.4975
Ke	Ganho do Observador de Estados	9.9948
Nx	Fator de Escala do Estado	1.0
Nu	Fator de Escala da Entrada	0.264

## 🛠️ Tecnologias Utilizadas
### Hardware:

Microcontrolador ESP32

Sensor Ultrassônico HC-SR04

Driver de Motor Ponte H L298N

Bomba de Água Submersível 12V

Fita de LED 12V para feedback de status

### Software e Protocolos:

Flutter (Dart)

C++ (Arduino Framework com FreeRTOS)

Protocolo MQTT

Bluetooth Low Energy (BLE)
