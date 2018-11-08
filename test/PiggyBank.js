const BigNumber = web3.BigNumber;
const expect = require('chai').expect;
const should = require('chai')
    .use(require('chai-as-promised'))
    .use(require('chai-bignumber')(web3.BigNumber))
    .should();

import expectThrow from './helpers/expectThrow';

var PiggyBank = artifacts.require('./PiggyBank.sol');

const setNextBlockDelay = function(duration) {
    const id = Date.now()

    return new Promise((resolve, reject) => {
        web3.currentProvider.sendAsync({
            jsonrpc: '2.0',
            method: 'evm_increaseTime',
            params: [duration],
            id: id,
        }, err1 => {
            if (err1) return reject(err1)

            web3.currentProvider.sendAsync({
                jsonrpc: '2.0',
                method: 'evm_mine',
                id: id+1,
            }, (err2, res) => {
                return err2 ? reject(err2) : resolve(res)
            })
        })
    })
}


function getRound(round) {
    if (round == undefined)
        return undefined;

    return {
        endTime: round[0].toNumber(),
        cap: round[1].toNumber(),
        lastBetIndex: round[2].toNumber(),
        winner: round[3]
    }
}

function getBet(bet) {
    if (bet == undefined)
        return undefined;

    return {
        minSum: bet[0].toNumber(),
        cooldown: bet[1].toNumber()
    }
}

contract('PiggyBank', function(accounts) {
    let piggyBank;

    const owner = accounts[0];
    const user0 = accounts[1];
    const user1 = accounts[2];
    const user2 = accounts[3];

    beforeEach('setup contract for each test', async function () {
        piggyBank = await PiggyBank.new({from: owner});
    });

    it('has an owner', async function () {
        expect(await piggyBank.owner()).to.equal(owner);
    });

    it('deposit', async function () {
        let sum = web3.toWei(1, 'ether');
        await piggyBank.deposit({from: user0, value: sum})
    });

    it('create round', async function () {
        // rounds doesn't exist first round
        await expectThrow(piggyBank.rounds(0))

        let ownerPercent = (await piggyBank.ownerDistribution()).toNumber();
        let bet0 = getBet(await piggyBank.getBet(0));

        await expectThrow(piggyBank.deposit({from: user0, value: bet0.minSum-2}))
        await piggyBank.deposit({from: user0, value: bet0.minSum});

        let round0 = getRound(await piggyBank.rounds(0));

        expect(round0.cap).to.equal(bet0.minSum * (100 - ownerPercent) / 100);
        expect(round0.winner).to.equal(user0);
    });

    it('win round', async function () {
        let bet0 = getBet(await piggyBank.getBet(0));
        let user0_balance_old = web3.eth.getBalance(user0).toNumber();

        let deposit_receipt = await piggyBank.deposit({from: user0, value: bet0.minSum});
        await setNextBlockDelay(bet0.cooldown + 2);
        let pay_receipt = await piggyBank.payWinCap({from: user0, gasPrice: 0});

        let round0 = getRound(await piggyBank.rounds(0));
        let user0_balance = web3.eth.getBalance(user0).toNumber();

        assert(user0_balance_old - user0_balance + round0.cap >= bet0.minSum);
    });

    it('win any round', async function () {
        let betsCount = (await piggyBank.betsCount()).toNumber();

        for (var i = 0; i < 26; i++) {
            piggyBank = await PiggyBank.new({from: owner});

            let bet = getBet(await piggyBank.getBet(i));
            let user0_balance_old = web3.eth.getBalance(user0).toNumber();

            let deposit_receipt = await piggyBank.deposit({from: user0, value: bet.minSum});
            await setNextBlockDelay(bet.cooldown + 2);
            let pay_receipt = await piggyBank.payWinCap({from: user0, gasPrice: 0});

            let round0 = getRound(await piggyBank.rounds(0));
            let user0_balance = web3.eth.getBalance(user0).toNumber();

            assert(user0_balance_old - user0_balance + round0.cap >= bet.minSum, 'fail ' + i + ' bet round');
        }
    });

    it('winner is', async function () {
        let betsCount = (await piggyBank.betsCount()).toNumber();
        let bet0 = getBet(await piggyBank.getBet(0));

        // deposit first user
        await piggyBank.deposit({from: user0, value: bet0.minSum});
        var round0 = getRound(await piggyBank.rounds(0));
        expect(round0.winner).to.equal(user0);

        // deposit second user
        await piggyBank.deposit({from: user1, value: bet0.minSum});
        round0 = getRound(await piggyBank.rounds(0));
        expect(round0.winner).to.equal(user1);

        for (var i = 0; i < betsCount; i++) {
            let bet = getBet(await piggyBank.getBet(i));
            await piggyBank.deposit({from: accounts[i], value: bet.minSum});
            round0 = getRound(await piggyBank.rounds(0));
            expect(round0.winner).to.equal(accounts[i]);
        }
    });

});
