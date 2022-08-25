from brownie import accounts, chain, Contract, IncentiveEarner, LiquidityZap, Pool2Incentives, ZERO_ADDRESS
import pytest

EPS_LP = '0x6B46dFaC1E46f059cea6C0a2D7642d58e8BE71F8'
DD_LP = '0xbFa075679a6c47D619269F854adD50C965d5cC64'
LP_DEPOSITOR = '0x8189F0afdBf8fE6a9e13c69bA35528ac6abeB1af'
MASTER_CHEF = '0x3eB63cff72f8687f8DE64b2f0e40a5B95302D028'
DISTRIBUTOR = '0x685D3b02b9b0F044A3C01Dbb95408FC2eB15a3b3'
DD_LOCKER = '0x51133C54b7bb6CC89DaC86B73c75B1bf98070e0d'
DD_VOTING = '0x5e4b853944f54C8Cb568b25d269Cd297B8cEE36d'
EPX = '0xAf41054C1487b0e5E2B9250C0332eCBCe6CE9d71'
DDD = '0x84c97300a190676a19D1E13115629A11f8482Bd1'
BONDING = '0xd4F7b4BC46e6e499D35335D270fd094979D815A0'
LP_AMOUNT = 10_000_000_000_000_000_000_000

@pytest.fixture(scope="function", autouse=True)
def setup():
    chain.reset()

@pytest.fixture
def deployer():
    return accounts[0]

@pytest.fixture
def acc():
    return accounts[1]

@pytest.fixture
def chef():
    return Contract(MASTER_CHEF)

@pytest.fixture
def incentives(deployer, chef):
    earner_impl = IncentiveEarner.deploy({'from': deployer})
    incentives = Pool2Incentives.deploy(earner_impl, {'from': deployer})
    chef_owner = accounts.at(chef.owner(), True)
    chef.addPool(incentives, 100, {'from': chef_owner})
    return incentives

@pytest.fixture
def eps_lp(acc):
    eps_lp = Contract(EPS_LP)
    eps_lp_minter = accounts.at(eps_lp.minter(), True)
    eps_lp.mint(acc, LP_AMOUNT, {'from': eps_lp_minter})
    return eps_lp

@pytest.fixture
def dd_lp(acc, eps_lp):
    depositor = Contract(LP_DEPOSITOR)
    eps_lp.approve(LP_DEPOSITOR, 2**256-1, {'from': acc})
    depositor.deposit(acc, EPS_LP, LP_AMOUNT, {'from': acc})
    dd_lp = Contract(DD_LP)
    return dd_lp

@pytest.fixture
def zap(deployer, incentives):
    zap = LiquidityZap.deploy(incentives, {'from': deployer})
    return zap

def test_deposit(acc, incentives, dd_lp, chef):
    assert dd_lp.balanceOf(acc) == LP_AMOUNT
    dd_lp.approve(incentives, 2**256-1, {'from': acc})
    assert incentives.earners(acc) == ZERO_ADDRESS
    assert incentives.lpBalance(acc) == 0
    assert incentives.totalSupply() == 0
    incentives.deposit(acc, LP_AMOUNT, {'from': acc})

    assert dd_lp.balanceOf(acc) == 0
    earner = incentives.earners(acc)
    assert earner != ZERO_ADDRESS
    assert dd_lp.balanceOf(earner) == LP_AMOUNT
    assert incentives.lpBalance(acc) == LP_AMOUNT
    assert incentives.balanceOf(chef) == LP_AMOUNT
    assert incentives.totalSupply() == LP_AMOUNT
    earner = IncentiveEarner.at(earner)
    assert earner.owner() == acc.address
    assert chef.userInfo(incentives, earner)[0] == LP_AMOUNT
    assert chef.claimReceiver(earner) == acc

def test_claimable(acc, incentives, dd_lp):
    dd_lp.approve(incentives, 2**256-1, {'from': acc})
    incentives.deposit(acc, LP_AMOUNT, {'from': acc})
    assert incentives.claimable(acc) == (0, 0, 0, ())

    chain.sleep(3600)
    chain.mine()

    claimable = incentives.claimable(acc)
    for i in range(3):
        assert claimable[i] > 0

def test_claim_valas(acc, incentives, dd_lp):
    dd_lp.approve(incentives, 2**256-1, {'from': acc})
    incentives.deposit(acc, LP_AMOUNT, {'from': acc})

    chain.sleep(3600)
    chain.mine()

    # Claim VALAS rewards
    distr = Contract(DISTRIBUTOR)
    assert distr.earnedBalances(acc)[0] == 0
    incentives.claim_valas({'from': acc})
    assert distr.earnedBalances(acc)[0] > 0
    assert incentives.claimable(acc)[0] == 0

def test_claim_dd(acc, incentives, dd_lp):
    dd_lp.approve(incentives, 2**256-1, {'from': acc})
    incentives.deposit(acc, LP_AMOUNT, {'from': acc})
    earner = incentives.earners(acc)

    chain.sleep(3600)
    chain.mine()

    # Claim EPX and DDD rewards
    epx = Contract(EPX)
    ddd = Contract(DDD)
    ddd.approve(incentives, 2**256-1, {'from': acc})
    locker = Contract(DD_LOCKER)
    bonding = Contract(BONDING)
    assert epx.balanceOf(acc) == 0 and bonding.bondedBalance(acc) == 0 and ddd.balanceOf(acc) == 0
    assert len(locker.getActiveUserLocks(incentives)) == 0
    incentives.claim_dotdot(0, {'from': acc})
    assert epx.balanceOf(acc) > 0 and bonding.bondedBalance(acc) == 0 and ddd.balanceOf(acc) > 0
    assert epx.balanceOf(earner) == 0 and bonding.bondedBalance(earner) == 0 and ddd.balanceOf(earner) == 0
    locks = locker.getActiveUserLocks(incentives)
    assert len(locks) == 1
    assert locks[0][0] == 16 and locks[0][1] > 0

def test_claim_dd_bond(acc, incentives, dd_lp):
    dd_lp.approve(incentives, 2**256-1, {'from': acc})
    incentives.deposit(acc, LP_AMOUNT, {'from': acc})
    earner = incentives.earners(acc)

    chain.sleep(3600)
    chain.mine()

    # Claim dEPX and DDD rewards
    epx = Contract(EPX)
    ddd = Contract(DDD)
    ddd.approve(incentives, 2**256-1, {'from': acc})
    bonding = Contract(BONDING)
    assert epx.balanceOf(acc) == 0 and bonding.bondedBalance(acc) == 0 and ddd.balanceOf(acc) == 0
    incentives.claim_dotdot(2**256 - 1, {'from': acc})
    assert epx.balanceOf(acc) == 0 and bonding.bondedBalance(acc) > 0 and ddd.balanceOf(acc) > 0
    assert epx.balanceOf(earner) == 0 and bonding.bondedBalance(earner) == 0 and ddd.balanceOf(earner) == 0

def test_vote(acc, incentives, dd_lp):
    dd_lp.approve(incentives, 2**256-1, {'from': acc})
    incentives.deposit(acc, LP_AMOUNT, {'from': acc})

    chain.sleep(3600)
    chain.mine()

    day = 24*3600
    week = 7*day
    Contract(DDD).approve(incentives, 2**256-1, {'from': acc})
    incentives.claim_dotdot(0, {'from': acc})
    t = (chain.time()//week + 1)*week + 5*day
    chain.mine(timestamp=t)
    locker = Contract(DD_LOCKER)
    locks = locker.getActiveUserLocks(incentives)
    assert locks[0][0] < 16
    incentives.extend_lock(locks[0][1], locks[0][0], {'from': acc})
    locks = locker.getActiveUserLocks(incentives)
    assert locks[0][0] == 16

    voting = Contract(DD_VOTING)
    eps_voting = Contract(voting.epsVoter())
    w = eps_voting.getWeek()
    votes = voting.availableVotes(incentives)
    assert votes > 0
    assert eps_voting.tokenVotes(EPS_LP, w) == 0
    incentives.vote(votes)
    assert voting.availableVotes(incentives) == 0
    assert eps_voting.tokenVotes(EPS_LP, w) > 0

def test_withdraw(acc, incentives, dd_lp, chef):
    dd_lp.approve(incentives, 2**256-1, {'from': acc})
    incentives.deposit(acc, LP_AMOUNT, {'from': acc})

    incentives.withdraw(acc, LP_AMOUNT, {'from': acc})
    earner = IncentiveEarner.at(incentives.earners(acc))
    assert dd_lp.balanceOf(acc) == LP_AMOUNT
    assert dd_lp.balanceOf(earner) == 0
    assert incentives.lpBalance(acc) == 0
    assert incentives.balanceOf(chef) == 0
    assert incentives.totalSupply() == 0
    assert chef.userInfo(incentives, earner)[0] == 0

def test_withdraw_eps(acc, incentives, eps_lp, dd_lp, chef):
    dd_lp.approve(incentives, 2**256-1, {'from': acc})
    incentives.deposit(acc, LP_AMOUNT, {'from': acc})

    incentives.withdraw_eps(acc, LP_AMOUNT, {'from': acc})
    earner = IncentiveEarner.at(incentives.earners(acc))
    assert dd_lp.balanceOf(acc) == 0
    assert dd_lp.balanceOf(earner) == 0
    assert eps_lp.balanceOf(acc) == LP_AMOUNT
    assert incentives.lpBalance(acc) == 0
    assert incentives.balanceOf(chef) == 0
    assert incentives.totalSupply() == 0
    assert chef.userInfo(incentives, earner)[0] == 0

def test_zap_deposit(acc, eps_lp, incentives, zap):
    eps_lp.approve(zap, 2**256-1, {'from': acc})
    assert incentives.lpBalance(acc) == 0
    zap.deposit(acc, LP_AMOUNT, {'from': acc})
    assert incentives.lpBalance(acc) == LP_AMOUNT

def test_zap_migrate(acc, incentives, zap):
    valas = Contract(zap.valas())
    wbnb = Contract(zap.wbnb())
    cake_lp = Contract(zap.cakeLpToken())

    valas_minter = accounts.at(valas.minter(), True)
    valas_amt = int(1e24)
    valas.mint(acc, valas_amt, {'from': valas_minter})
    valas.transfer(cake_lp, valas_amt, {'from': acc})
    
    reserves = cake_lp.getReserves()
    bnb_amt = int(reserves[1]*valas_amt//reserves[0])
    wbnb.deposit({'from': acc, 'value': bnb_amt})
    wbnb.transfer(cake_lp, bnb_amt, {'from': acc})

    cake_lp.mint(acc, {'from': acc})
    cake_lp_amt = cake_lp.balanceOf(acc)
    cake_lp.approve(zap, 2**256-1, {'from': acc})

    assert incentives.lpBalance(acc) == 0
    zap.migrate(acc, cake_lp_amt, valas_amt*99//100, bnb_amt*99//100, 0, chain.time() + 60, {'from': acc})
    assert incentives.lpBalance(acc) > 0
