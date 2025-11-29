# DeFi Flash Loan Implementation (Aave V2)

Projeto de Prova de Conceito (PoC) que implementa um *Flash Loan* (Empréstimo Rápido) através do protocolo Aave V2, demonstrando a interação com *Smart Contracts* de terceiros e a lógica complexa de transações atômicas no ecossistema DeFi.

## 🔗 Tecnologias e Ferramentas

* **Linguagem:** Solidity (versão ^0.8.0)
* **Protocolo:** Aave V2
* **Ambiente de Desenvolvimento:** Hardhat (para testes e deploy local)
* **Testes:** Chai / Mocha
* **Conceitos:** ERC-20, Callbacks (como `executeOperation` da Aave)

## 💡 Conceitos Chave Demonstrados

* **Transações Atômicas:** A execução completa do empréstimo, arbitragem e pagamento (juros) dentro de uma única transação.
* **Interação com Protocolos:** Demonstração de como contratos podem interagir com o *Liquidity Pool* da Aave.
* **Segurança:** Uso de *Modifiers* para restringir chamadas externas.
* **Testes Robustos:** Estrutura de testes para garantir que a transação falhe se a condição do empréstimo não for atendida.

## ⚙️ Como Testar

1.  Clone o repositório.
2.  Instale o Hardhat e dependências: `npm install`
3.  Compile os contratos: `npx hardhat compile`
4.  Execute os testes: `npx hardhat test` (Os testes simulam o fluxo completo do *Flash Loan*).
