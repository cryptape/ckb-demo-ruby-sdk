# How to use

## Prerequisites

First you will need to have [ckb](https://github.com/nervosnetwork/ckb) compiled of course. Feel free to just following the official build steps in the README. We will customize configs later.

You will also need [mruby-contracts](https://github.com/nervosnetwork/mruby-contracts). Follow the steps in the README to build it, you will need the generated mruby contract file at `build/argv_source_entry`.

If you don't want to build mruby-contracts yourself, we have a prebuilt binary at [here](https://github.com/nervosnetwork/binary/raw/master/contracts/mruby/argv_source_entry).

## Configure CKB

First, follow the [README](https://github.com/nervosnetwork/ckb/blob/develop/README.md) steps to make sure CKB is up and running.

There's only one required step you need to perform: make sure the miner process is using the correct type hash. To do this, first make sure you are in CKB's repo directory, and use the following command:

```bash
$ ./target/release/ckb cli type_hash
0x8954a4ac5e5c33eb7aa8bb91e0a000179708157729859bd8cf7e2278e1e12980
```

Note that you might need to adjust this command if:

1. You are building debug version instead of release version
2. You use a custom config file.

Then locate `default.toml` file in your config directory, navigate to miner section, change `type_hash` field to the value you get in the above command. Notice you will need to restart miner process after this change.

There're also optional steps here which would help you when you are using the SDK but not required:

### Use Dummy POW mode

By default, CKB is running Cuckoo POW algorithm, depending on the computing power your machine has, this might slow things down.

To change to Dummy POW mode, which merely sleeps randomly for a few seconds before issuing a block, please locate `spec/dev.toml` file in your config directory, nagivate to `pow` section, and change the config to the following:

```toml
[pow]
func = "Dummy"
```

Then delete `[pow.params]`

This way you will be using Dummy POW mode, note that if you have run CKB before, you need to clean data directory (which is `nodes/default` by default) and restart CKB process as well as miner process.

### Enlarge miner reward

By default, CKB issues 50000 capacities to a block, however, since we will need to install a binary which is roughly 1.6MB here, it might take quite a while for CKB to miner enough capacities. So you might want to enlarge miner reward to speedup this process.

To do this, locate `spec/dev.toml` file in your config directory, navigate to `params` section, and adjust `initial_block_reward` field to the following:

```toml
initial_block_reward = 5000000
```

Note that if you have run CKB before, you need to clean data directory (which is `nodes/default` by default) and restart CKB process as well as miner process.

### Custom log config

By default CKB doesn't emit any debug log entries, but when you are playing with the SDK, chances are you will be interested in certain debug logs.

To change this, locate `default.toml` file in your config directory, navigate to `logger` section, and adjust `filter` field to the following:

```toml
filter = "info,chain=debug,script=debug"
```

Now when you restart your CKB main process, you will have debug log entries from `chain` and `script` modules, which will be quite useful when you play with this SDK.

## Running SDK

Now we can setup the Ruby SDK:

```bash
$ git clone --recursive https://github.com/nervosnetwork/ckb-demo-ruby-sdk
$ cd ckb-demo-ruby-sdk
$ bundle
$ bundle exec pry -r ./lib/ckb/wallet.rb
[1] pry(main)> api = Ckb::Api.new
[2] pry(main)> api.get_tip_number
28
```

Please be noted that the SDK depends on the [bitcoin-secp256k1](https://github.com/cryptape/ruby-bitcoin-secp256k1) gem and the [rbnacl](https://github.com/crypto-rb/rbnacl) gem, which require manual install of secp256k1 and libsodium library. Follow [this](https://github.com/cryptape/ruby-bitcoin-secp256k1#prerequisite) and [this](https://github.com/crypto-rb/rbnacl#installation) to install them locally.

In the Ruby shell, we can start playing with the SDK.

### Install mruby contract

First, we will need the `argv_source_entry` file as mentioned in `Prerequisite` section and preprocess it a bit. The following steps assume that the file and the processed file are all in directory `/path/to/`:

```bash
$ git clone https://github.com/nervosnetwork/ckb-binary-to-script
$ cd ckb-binary-to-script
$ cargo build
$ ./target/debug/ckb-binary-to-script < /path/to/argv_source_entry > /path/to/processed_argv_source_entry
```

Notice this preprocessing step is only needed since Ruby doesn't have a FlatBuffers implementation, for another language, we can build this preprocessing step directly in the SDK.

Then we can install this mruby contract into CKB:

```ruby
[1] pry(main)> asw = Ckb::AlwaysSuccessWallet.new(api)
[2] pry(main)> conf = asw.install_mruby_cell!("/path/to/processed_argv_source_entry")
=> {:out_point=>{:hash=>"0x20b849ffe67eb5872eca0d68fff1de193f07354ea903948ade6a3c170d89e282", :index=>0},
 :cell_hash=>"0x03dba46071a6702b39c1e626f469b4ed9460ed0ad92cf2e21456c34e1e2b04fd"}
[3] pry(main)> asw.configuration_installed?(conf)
=> false
[3] pry(main)> # Wait a while till this becomes true
[4] pry(main)> asw.configuration_installed?(conf)
=> true
```

Now you have the mruby contract installed in CKB, and the relavant configuration in `conf` structure. You can inform `api` object to use this configuration:

```ruby
[1] pry(main)> api.set_and_save_default_configuration!(conf)
```

Notice this line also saves the configuration to a local file, so next time when you are opening a `pry` console, you only need to load the save configuration:

```ruby
[1] pry(main)> api = Ckb::Api.new
[2] pry(main)> api.load_default_configuration!
```

Only when you clear the data directory in the CKB node, or switch to a different CKB node, will you need to perform the above installations again.

### Basic wallet

To play with wallets, first we need to add some capacities to a wallet:

```bash
[1] pry(main)> bob = Ckb::Wallet.from_hex(api, "e79f3207ea4980b7fed79956d5934249ceac4751a4fae01a0f7c4a96884bc4e3")
[2] pry(main)> bob.get_balance
=> 0
[3] pry(main)> asw.send_capacity(bob.address, 100000)
[4] pry(main)> # wait a while
[5] pry(main)> bob.get_balance
=> 100000
```

Now we can perform normal transfers between wallets:

```bash
[1] pry(main)> bob = Ckb::Wallet.from_hex(api, "e79f3207ea4980b7fed79956d5934249ceac4751a4fae01a0f7c4a96884bc4e3")
[2] pry(main)> alice = Ckb::Wallet.from_hex(api, "76e853efa8245389e33f6fe49dcbd359eb56be2f6c3594e12521d2a806d32156")
[3] pry(main)> bob.get_balance
=> 100000
[4] pry(main)> alice.get_balance
=> 0
[5] pry(main)> bob.send_capacity(alice.address, 12345)
=> "0xd7abc1407eb07d334fea86ef0e9b12b2273833137327c2a53f2d8ba1be1e4d85"
[6] pry(main)> # wait for some time
[7] pry(main)> alice.get_balance
=> 12345
[8] pry(main)> bob.get_balance
=> 87655
```

### User defined token with lock

We can also create user defined token that's separate from CKB. A new user defined token is made of 2 parts:

* A token name
* Token's admin pubkey, only token's admin can issue new tokens. Other user can only transfer already created tokens to others.

Ruby SDK here provides an easy way to create a token from an existing wallet

```bash
[1] pry(main)> bob = Ckb::Wallet.from_hex(api, "e79f3207ea4980b7fed79956d5934249ceac4751a4fae01a0f7c4a96884bc4e3")
[2] pry(main)> alice = Ckb::Wallet.from_hex(api, "76e853efa8245389e33f6fe49dcbd359eb56be2f6c3594e12521d2a806d32156")
[3] pry(main)> token_info = bob.created_token_info("Token 1")
=> #<Ckb::TokenInfo:0x0000561fee8cf550 @name="Token 1", @pubkey="024a501efd328e062c8675f2365970728c859c592beeefd6be8ead3d901330bc01">
[4] pry(main)> # token info represents the meta data for a token
[5] pry(main)> # we can assemble a wallet for user defined token with token info structure
[6] pry(main)> bob_token1 = bob.udt_wallet(token_info)
[7] pry(main)> alice_token1 = alice.udt_wallet(token_info)
```

Now we can create this token from a user with CKB capacities(since the cell used to hold the tokens will take some capacity):

```bash
[9] pry(main)> bob.get_balance
=> 87655
[10] pry(main)> # here we are creating 10000000 tokens for "Token 1", we put those tokens in a cell with 10000 CKB capacity
[11] pry(main)> bob.create_udt_token(10000, "Token 1", 10000000)
[12] pry(main)> bob_token1.get_balance
=> 10000000
[13] pry(main)> alice_token1.get_balance
=> 0
```

Now that the token is created, we can implement a token transfer process between CKB capacities and user defined tokens. Specifically, we are demostrating the following process:

* Alice signs signatures providing a certain number of CKB capacities in exchange of some user defined tokens. Notice CKB contracts here can ensure that no one can spend alice's signed capacities without providing tokens for Alice
* Then bob provides user defined tokens for Alice in exchange for Alice's capacities.

Notice CKB is flexible to implement many other types of transaction for this problem, here we are simply listing one solution here. You are not limited to only this solution.

The following code fulfills this step:

```bash
[15] pry(main)> # Alice is paying 10999 CKB capacities for 12345 token 1, alice will also spare 4104 CKB capacities to hold the returned token 1.
[15] pry(main)> partial_tx = alice_token1.generate_partial_tx_for_udt_cell(12345, 4104, 10999)
[18] pry(main)> bob_token1.send_amount(12345, partial_tx)
[19] pry(main)> bob_token1.get_balance
=> 9987655
[20] pry(main)> alice_token1.get_balance
=> 12345
```

#### Deposit

Now bob could deposit 5000 token

```bash
[9] pry(main)> bob.get_balance
=> 990000
pry(main)> bob_token1.deposit(5000, 5000)
=> "0x70fa60737916afba3c8b8a2e7e9a6e8fe8514a1a96658f0e659aa2c4f834ca47"
[10] pry(main)> bob_token1.get_balance
=> 9995000
[11] pry(main)> bob_token1.get_deposit_balance
=> 5000
```

We can get all the cells belong to bob.

```
[13] pry(main)> bob_token1.get_unspent_cells_including_deposit
=> [{:capacity=>4104,
  :lock=>"0x7b1f6486ce8fddeae8e5242f9332b7bbb5a595421a445951269aa1beb5d74b81",
  :out_point=>{:hash=>"0x70fa60737916afba3c8b8a2e7e9a6e8fe8514a1a96658f0e659aa2c4f834ca47", :index=>0},
  :amount=>5000,
  :status=>1},
 {:capacity=>5896,
  :lock=>"0x7b1f6486ce8fddeae8e5242f9332b7bbb5a595421a445951269aa1beb5d74b81",
  :out_point=>{:hash=>"0x70fa60737916afba3c8b8a2e7e9a6e8fe8514a1a96658f0e659aa2c4f834ca47", :index=>1},
  :amount=>9995000,
  :status=>0}]
```
We could see that bob owns 5000 tokens in stauts 1 (indicated it's locked), and 9995000 tokens in status 0.

Note: now this's just a draft implementation. The locked token capacity is just detached from the origin token. So please keep the origin token has enough capacity. Later we should provide a method to fill the locked token in some vacant cells.

#### Exit

User could exit the locked token.

```
[7] pry(main)> bob_token1.get_deposit_balance
=> 5000
[8] pry(main)> bob_token1.get_balance
=> 9995000
[9] pry(main)> deposit_cell = bob_token1.deposit_cells[0]
=> {:capacity=>4104,
 :lock=>"0x7b1f6486ce8fddeae8e5242f9332b7bbb5a595421a445951269aa1beb5d74b81",
 :out_point=>{:hash=>"0x70fa60737916afba3c8b8a2e7e9a6e8fe8514a1a96658f0e659aa2c4f834ca47", :index=>0},
 :amount=>5000,
 :status=>1}
[10] pry(main)> bob_token1.exit(deposit_cell)
=> "0x5b00b11778c735d7e84e22b2003d247e0a5b6de0a0bbecf5af53d1c2ec61bb34"
[11] pry(main)> bob_token1.get_balance
=> 10000000
[12] pry(main)> bob_token1.get_deposit_balance
=> 0
```

Note: now this's just a draft implementation. The exit action should check the provied proof and should exit from part of locked tokens or multiple tokens.

### User Defined Token which uses only one cell per wallet:

```bash
[1] pry(main)> bob = Ckb::Wallet.from_hex(api, "e79f3207ea4980b7fed79956d5934249ceac4751a4fae01a0f7c4a96884bc4e3")
[2] pry(main)> alice = Ckb::Wallet.from_hex(api, "76e853efa8245389e33f6fe49dcbd359eb56be2f6c3594e12521d2a806d32156")
[3] pry(main)> token_info2 = bob.created_token_info("Token 2", account_wallet: true)
[4] pry(main)> bob_cell_token2 = bob.udt_account_wallet(token_info2)
[5] pry(main)> alice_cell_token2 = alice.udt_account_wallet(token_info2)
[6] pry(main)> bob.create_udt_token(10000, "Token 2", 10000000, account_wallet: true)
[7] pry(main)> alice.create_udt_account_wallet_cell(3010, token_info2)
[8] pry(main)> bob_cell_token2.send_tokens(12345, alice_cell_token2)
[9] pry(main)> bob_cell_token2.get_balance
=> 9987655
[10] pry(main)> alice_cell_token2.get_balance
=> 12345
```

NOTE: While it might be possible to mix the 2 ways of using user defined token above in one token, we don't really recommend that since it could be the source of a lot of confusions.

### User Defined Token with a fixed upper cap

We have also designed a user defined token with a fixed upper cap. For this type of token, the token amount is set when it is initially created, there's no way to create more tokens after that.

```bash
[1] pry(main)> bob = Ckb::Wallet.from_hex(api, "e79f3207ea4980b7fed79956d5934249ceac4751a4fae01a0f7c4a96884bc4e3")
[2] pry(main)> alice = Ckb::Wallet.from_hex(api, "76e853efa8245389e33f6fe49dcbd359eb56be2f6c3594e12521d2a806d32156")
# Create a genesis UDT cell with 10000 capacity, the UDT has a fixed amount of 10000000.
# The initial exchange rate is 1 capacity for 5 tokens.
[3] pry(main)> result = alice.create_fixed_amount_token(10000, 10000000, 5)
[4] pry(main)> fixed_token_info = result.token_info
# Creates a UDT wallet that uses only one cell, the cell has a capacity of 11111
[5] pry(main)> alice.create_udt_account_wallet_cell(11111, fixed_token_info)
# Purchase 500 UDT tokens
[6] pry(main)> alice.purchase_fixed_amount_token(500, fixed_token_info)
# Wait for a while here...
[7] pry(main)> alice.udt_account_wallet(fixed_token_info).get_balance
```

### Block first submission

```bash
[1] pry(main)> api = Ckb::Api.new
=> #<API@http://localhost:8114>
[2] pry(main)> api.get_tip_number
=> 4787
[3] pry(main)> api.load_default_configuration!
=> "0x00ccb858f841db7ece8833a77de158b84af4c8f43a69dbb0f43de87faabfde32"
[4] pry(main)> bob = Ckb::Wallet.from_hex(api, "e79f3207ea4980b7fed79956d5934249ceac4751a4fae01a0f7c4a96884bc4e3")
=> #<Ckb::Wallet:0x000055ca1a4d4e98 @api=#<API@http://localhost:8114>, @privkey="\xE7\x9F2\a\xEAI\x80\xB7\xFE\xD7\x99V\xD5\x93BI\xCE\xACGQ\xA4\xFA\xE0\x1A\x0F|J\x96\x88K\xC4\xE3">
[5] pry(main)> chain = Ckb::Chain::new(api, "plasma", Ckb::Utils.bin_to_hex(Ckb::Utils.extract_pubkey_bin(bob.privkey)))
=> #<Ckb::Chain:0x000055ca1a47da08 @api=#<API@http://localhost:8114>, @name="plasma", @pubkey="024a501efd328e062c8675f2365970728c859c592beeefd6be8ead3d901330bc01">
[6] pry(main)> bob.commit_first_block(chain, 7411112, "0x6afcc9af62d92f1695d3456cc2d818e38b5ccf92a6b7c907647da274722e44ce", 1000000)
[7] pry(main)> tx=api.get_transaction("0xb9578b4a2e1d6e809dc685c5355ebd0727a8fa5ad7d99d1fdaa54ab0db3c58aa")
=> {:deps=>[{:hash=>"0xf8e9ce37d925d7360cb17f6510307ad75ed4c7b38a2b1965063125a2da031553", :index=>0}],
 :hash=>"0xb9578b4a2e1d6e809dc685c5355ebd0727a8fa5ad7d99d1fdaa54ab0db3c58aa",
 :inputs=>
  [{:previous_output=>{:hash=>"0x991b22853ae1599cb9e60ba9a8c641bce280a96eea9fe664da135cddafe71303", :index=>0},
    :unlock=>
     {:args=>
       ["0x33303435303232313030613932643837303961623866323637343266343736623663346563366365303966373166326633613964303930623535646266396165613138356536306466343032323031653434636435633462633531633961393033393237636361666361393333623530353033653935383966333237326238306465343339393538356134393736",
        "0x31"],
      :binary=>nil,
      :reference=>"0x00ccb858f841db7ece8833a77de158b84af4c8f43a69dbb0f43de87faabfde32",
      :signed_args=>
       ["0x23205468697320636f6e7472616374206e656564732031207369676e656420617267756d656e74733a0a2320302e207075626b65792c207573656420746f206964656e7469667920746f6b656e206f776e65720a23205468697320636f6e74726163747320616c736f2061636365707473203220726571756972656420756e7369676e656420617267756d656e747320616e6420310a23206f7074696f6e616c20756e7369676e656420617267756d656e743a0a2320312e207369676e61747572652c207369676e6174757265207573656420746f2070726573656e74206f776e6572736869700a2320322e20747970652c205349474841534820747970650a2320332e206f75747075742873292c2074686973206973206f6e6c79207573656420666f7220534947484153485f53494e474c4520616e6420534947484153485f4d554c5449504c452074797065732c0a2320666f7220534947484153485f53494e474c452c2069742073746f72657320616e20696e74656765722064656e6f74696e672074686520696e646578206f66206f757470757420746f2062650a23207369676e65643b20666f7220534947484153485f4d554c5449504c452c2069742073746f726573206120737472696e67206f6620602c60207365706172617465642061727261792064656e6f74696e670a23206f75747075747320746f207369676e0a696620415247562e6c656e67746820213d203320262620415247562e6c656e67746820213d20340a20207261697365202257726f6e67206e756d626572206f6620617267756d656e747321220a656e640a0a534947484153485f414c4c203d203078310a534947484153485f4e4f4e45203d203078320a534947484153485f53494e474c45203d203078330a534947484153485f4d554c5449504c45203d203078340a534947484153485f414e594f4e4543414e504159203d20307838300a0a646566206865785f746f5f62696e2873290a2020696620732e73746172745f776974683f2822307822290a2020202073203d20735b322e2e2d315d0a2020656e640a20205b735d2e7061636b2822482a22290a656e640a0a0a7478203d20434b422e6c6f61645f74780a626c616b653262203d20426c616b6532622e6e65770a0a626c616b6532622e75706461746528415247565b325d290a736967686173685f74797065203d20415247565b325d2e746f5f690a0a696620736967686173685f74797065202620534947484153485f414e594f4e4543414e50415920213d20300a202023204f6e6c7920686173682063757272656e7420696e7075740a20206f75745f706f696e74203d20434b422e6c6f61645f696e7075745f6f75745f706f696e7428302c20434b423a3a536f757263653a3a43555252454e54290a2020626c616b6532622e757064617465286f75745f706f696e745b2268617368225d290a2020626c616b6532622e757064617465286f75745f706f696e745b22696e646578225d2e746f5f73290a2020626c616b6532622e75706461746528434b423a3a43656c6c4669656c642e6e657728434b423a3a536f757263653a3a43555252454e542c20302c20434b423a3a43656c6c4669656c643a3a4c4f434b5f48415348292e72656164616c6c290a656c73650a202023204861736820616c6c20696e707574730a202074785b22696e70757473225d2e656163685f776974685f696e64657820646f207c696e7075742c20697c0a20202020626c616b6532622e75706461746528696e7075745b2268617368225d290a20202020626c616b6532622e75706461746528696e7075745b22696e646578225d2e746f5f73290a20202020626c616b6532622e75706461746528434b422e6c6f61645f7363726970745f6861736828692c20434b423a3a536f757263653a3a494e5055542c20434b423a3a43617465676f72793a3a4c4f434b29290a2020656e640a656e640a0a6361736520736967686173685f74797065202620287e534947484153485f414e594f4e4543414e504159290a7768656e20534947484153485f414c4c0a202074785b226f757470757473225d2e656163685f776974685f696e64657820646f207c6f75747075742c20697c0a20202020626c616b6532622e757064617465286f75747075745b226361706163697479225d2e746f5f73290a20202020626c616b6532622e757064617465286f75747075745b226c6f636b225d290a2020202069662068617368203d20434b422e6c6f61645f7363726970745f6861736828692c20434b423a3a536f757263653a3a4f55545055542c20434b423a3a43617465676f72793a3a54595045290a202020202020626c616b6532622e7570646174652868617368290a20202020656e640a2020656e640a7768656e20534947484153485f53494e474c450a2020726169736520224e6f7420656e6f75676820617267756d656e74732220756e6c65737320415247565b335d0a20206f75747075745f696e646578203d20415247565b335d2e746f5f690a20206f7574707574203d2074785b226f757470757473225d5b6f75747075745f696e6465785d0a2020626c616b6532622e757064617465286f75747075745b226361706163697479225d2e746f5f73290a2020626c616b6532622e757064617465286f75747075745b226c6f636b225d290a202069662068617368203d20434b422e6c6f61645f7363726970745f68617368286f75747075745f696e6465782c20434b423a3a536f757263653a3a4f55545055542c20434b423a3a43617465676f72793a3a54595045290a20202020626c616b6532622e7570646174652868617368290a2020656e640a7768656e20534947484153485f4d554c5449504c450a2020726169736520224e6f7420656e6f75676820617267756d656e74732220756e6c65737320415247565b335d0a2020415247565b335d2e73706c697428222c22292e6561636820646f207c6f75747075745f696e6465787c0a202020206f75747075745f696e646578203d206f75747075745f696e6465782e746f5f690a202020206f7574707574203d2074785b226f757470757473225d5b6f75747075745f696e6465785d0a20202020626c616b6532622e757064617465286f75747075745b226361706163697479225d2e746f5f73290a20202020626c616b6532622e757064617465286f75747075745b226c6f636b225d290a2020202069662068617368203d20434b422e6c6f61645f7363726970745f68617368286f75747075745f696e6465782c20434b423a3a536f757263653a3a4f55545055542c20434b423a3a43617465676f72793a3a54595045290a202020202020626c616b6532622e7570646174652868617368290a20202020656e640a2020656e640a656e640a68617368203d20626c616b6532622e66696e616c0a0a7075626b6579203d20415247565b305d0a7369676e6174757265203d20415247565b315d0a0a756e6c65737320536563703235366b312e766572696679286865785f746f5f62696e287075626b6579292c206865785f746f5f62696e287369676e6174757265292c2068617368290a2020726169736520225369676e617475726520766572696669636174696f6e206572726f7221220a656e640a",
        "0x303234613530316566643332386530363263383637356632333635393730373238633835396335393262656565666436626538656164336439303133333062633031"],
      :version=>0}}],
 :outputs=>
  [{:capacity=>1000000,
    :data=>"0x00000000000000000000000000000000000000000000000000000000000000006afcc9af62d92f1695d3456cc2d818e38b5ccf92a6b7c907647da274722e44cea815710000000000",
    :lock=>"0x82e4b4bfb752e1ccd293be2e020f07dee6e792f27259c1c44f8f325eced42b68",
    :type=>
     {:args=>
       ["0x3330343430323230316432373832306433613666613332346433353130313431376439323634663966376438316164303338643630626633303065653330316232663966666264303032323033373761653664363439316438363063376364343465663264373138343330623062323636653663636132326532303130343630383538623136396636626337"],
      :binary=>nil,
      :reference=>"0x00ccb858f841db7ece8833a77de158b84af4c8f43a69dbb0f43de87faabfde32",
      :signed_args=>
       ["0x23205468697320636f6e7472616374206e656564732032207369676e656420617267756d656e74733a0a2320302e20636861696e206e616d652c2074686973206973206a757374206120706c616365686f6c64657220746f2064697374696e6775697368206265747765656e20636861696e732c0a232069742077696c6c206e6f74206265207573656420696e207468652061637475616c20636f6e74726163742e205468652070616972206f6620636861696e206e616d6520616e640a23207075626b657920756e697175656c79206964656e746966696573206120636861696e2e0a2320312e207075626b65790a23205468697320636f6e7472616374206d6967687420616c736f206e656564203120756e7369676e656420617267756d656e743a0a2320322e207369676e61747572650a696620415247562e6c656e67746820213d20330a2020726169736520224e6f7420656e6f75676820617267756d656e747321220a656e640a0a646566206865785f746f5f62696e2873290a2020696620732e73746172745f776974683f2822307822290a2020202073203d20735b322e2e2d315d0a2020656e640a20205b735d2e7061636b2822482a22290a656e640a0a636f6e74726163745f747970655f68617368203d20434b422e6c6f61645f7363726970745f6861736828302c20434b423a3a536f757263653a3a43555252454e542c20434b423a3a43617465676f72793a3a54595045290a0a7478203d20434b422e6c6f61645f74780a0a6d6174636865645f696e70757473203d205b5d0a6d6174636865645f6f757470757473203d205b5d0a0a626c616b653262203d20426c616b6532622e6e65770a626c616b6532622e75706461746528636f6e74726163745f747970655f68617368290a74785b22696e70757473225d2e656163685f776974685f696e64657820646f207c696e7075742c20697c0a2020696620434b422e6c6f61645f7363726970745f6861736828692c20434b423a3a536f757263653a3a494e5055542c20434b423a3a43617465676f72793a3a5459504529203d3d20636f6e74726163745f747970655f686173680a202020206d6174636865645f696e70757473203c3c20690a20202020626c616b6532622e75706461746528434b423a3a43656c6c4669656c642e6e657728434b423a3a536f757263653a3a494e5055542c20692c20434b423a3a43656c6c4669656c643a3a44415441292e7265616428302c20373229290a2020656e640a656e640a74785b226f757470757473225d2e656163685f776974685f696e64657820646f207c6f75747075742c20697c0a202068617368203d20434b422e6c6f61645f7363726970745f6861736828692c20434b423a3a536f757263653a3a4f55545055542c20434b423a3a43617465676f72793a3a54595045290a202069662068617368203d3d20636f6e74726163745f747970655f686173680a202020206d6174636865645f6f757470757473203c3c20690a20202020626c616b6532622e75706461746528434b423a3a43656c6c4669656c642e6e657728434b423a3a536f757263653a3a4f55545055542c20692c20434b423a3a43656c6c4669656c643a3a44415441292e7265616428302c20373229290a2020656e640a656e640a0a64617461203d20626c616b6532622e66696e616c0a0a756e6c65737320536563703235366b312e766572696679286865785f746f5f62696e28415247565b315d292c206865785f746f5f62696e28415247565b325d292c2064617461290a2020726169736520225369676e617475726520766572696669636174696f6e206572726f7221220a656e640a0a69662021286d6174636865645f696e707574732e73697a65203d3d2030206f72206d6174636865645f696e707574732e73697a65203d3d2031290a20207261697365202257726f6e67206e756d626572206f66206d61746368656420696e7075747321220a656e640a0a6966206d6174636865645f6f7574707574732e73697a6520213d20310a20207261697365202257726f6e67206e756d626572206f66206d617463686564206f75747075747321220a656e640a0a2320666972737420636f6d6d69740a6966206d6174636865645f696e707574732e73697a65203d3d20300a2020232044617461203d205b636f6e6669726d65645f726f6f742c20756e636f6e6669726d65645f726f6f742c20626c6f636b4e756d6265725d0a2020232033322c2033322c2038203d20373242797465730a202064617461203d20434b423a3a43656c6c4669656c642e6e657728434b423a3a536f757263653a3a4f55545055542c206d6174636865645f696e707574735b305d2c20434b423a3a43656c6c4669656c643a3a44415441292e7265616428302c203732290a2020636f6e6669726d65642c20756e636f6e6669726d65642c20626c6f636b5f6e756d626572203d20646174612e756e7061636b2822483634483634513c22290a0a2020696620636f6e6669726d656420213d202230303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030220a2020202072616973652022496620666972737420636f6d6d69742c20657870656374656420303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030302c2062757420676f7420237b636f6e6669726d65647d220a2020656e640a656e640a0a6966206d6174636865645f696e707574732e73697a65203d3d20310a202064617461203d20434b423a3a43656c6c4669656c642e6e657728434b423a3a536f757263653a3a494e5055542c206d6174636865645f696e707574735b305d2c20434b423a3a43656c6c4669656c643a3a44415441292e7265616428302c203732290a2020696e7075745f636f6e6669726d65642c20696e7075745f756e636f6e6669726d65642c20696e7075745f626c6f636b5f6e756d626572203d20646174612e756e7061636b2822483634483634513c22290a0a202064617461203d20434b423a3a43656c6c4669656c642e6e657728434b423a3a536f757263653a3a4f55545055542c206d6174636865645f6f7574707574735b305d2c20434b423a3a43656c6c4669656c643a3a44415441292e7265616428302c203732290a20206f75747075745f636f6e6669726d65642c206f75747075745f756e636f6e6669726d65642c206f75747075745f626c6f636b5f6e756d626572203d20646174612e756e7061636b2822483634483634513c22290a20200a2020756e6c657373206f75747075745f626c6f636b5f6e756d626572203d3d20696e7075745f626c6f636b5f6e756d626572202b20310a2020202072616973652022426c6f636b4e756d62657220766572696669636174696f6e206572726f7221220a2020656e640a20200a2020756e6c65737320696e7075745f756e636f6e6669726d6564203d3d206f75747075745f636f6e6669726d65640a2020202072616973652022436f6e6669726d656420726f6f7420766572696669636174696f6e206572726f7221220a2020656e640a656e640a",
        "0x706c61736d61",
        "0x303234613530316566643332386530363263383637356632333635393730373238633835396335393262656565666436626538656164336439303133333062633031"],
      :version=>0}},
   {:capacity=>99000000, :data=>"0x", :lock=>"0xb777827acec016f62798659f5dadd19c85df81a470b3c9d3a2af13e28947b8dc", :type=>nil}],
 :version=>0}
[8] pry(main)> bob.get_balance
=> 99000000
[12] pry(main)> tx[:outputs][0][:data]
=> "0x00000000000000000000000000000000000000000000000000000000000000006afcc9af62d92f1695d3456cc2d818e38b5ccf92a6b7c907647da274722e44cea815710000000000"
[13] pry(main)> Ckb::Utils.hex_to_bin(tx[:outputs][0][:data]).unpack("H64H64Q<")
=> ["0000000000000000000000000000000000000000000000000000000000000000", "6afcc9af62d92f1695d3456cc2d818e38b5ccf92a6b7c907647da274722e44ce", 7411112]
```

### Block submission

```shell
[1] pry(main)> api = Ckb::Api.new
=> #<API@http://localhost:8114>
[2] pry(main)> api.get_tip_number
=> 5347
[3] pry(main)> api.load_default_configuration!
=> "0x00ccb858f841db7ece8833a77de158b84af4c8f43a69dbb0f43de87faabfde32"
[4] pry(main)> bob = Ckb::Wallet.from_hex(api, "e79f3207ea4980b7fed79956d5934249ceac4751a4fae01a0f7c4a96884bc4e3")
=> #<Ckb::Wallet:0x000055a32e99cdf8 @api=#<API@http://localhost:8114>, @privkey="\xE7\x9F2\a\xEAI\x80\xB7\xFE\xD7\x99V\xD5\x93BI\xCE\xACGQ\xA4\xFA\xE0\x1A\x0F|J\x96\x88K\xC4\xE3">
[5] pry(main)> chain = Ckb::Chain::new(api, "plasma", Ckb::Utils.bin_to_hex(Ckb::Utils.extract_pubkey_bin(bob.privkey)))
=> #<Ckb::Chain:0x000055a32e927c38 @api=#<API@http://localhost:8114>, @name="plasma", @pubkey="024a501efd328e062c8675f2365970728c859c592beeefd6be8ead3d901330bc01">
[6] pry(main)> cells = bob.get_block_cells(chain)
=> [{:capacity=>990000,
  :lock=>"0x82e4b4bfb752e1ccd293be2e020f07dee6e792f27259c1c44f8f325eced42b68",
  :out_point=>{:hash=>"0xa721c1c86ba6f0e8e834c56d8fd6a53a0ebd8d82840b8608a4c8647089481eb4", :index=>0},
  :confirmed=>"0000000000000000000000000000000000000000000000000000000000000000",
  :unconfirmed=>"51eb67b96f54f5263dcb102a3f532f9fdde9aa0c2aff4e4f42bda1ad1332081f",
  :block_number=>7411111},
 {:capacity=>1000000,
  :lock=>"0x82e4b4bfb752e1ccd293be2e020f07dee6e792f27259c1c44f8f325eced42b68",
  :out_point=>{:hash=>"0xb9578b4a2e1d6e809dc685c5355ebd0727a8fa5ad7d99d1fdaa54ab0db3c58aa", :index=>0},
  :confirmed=>"0000000000000000000000000000000000000000000000000000000000000000",
  :unconfirmed=>"6afcc9af62d92f1695d3456cc2d818e38b5ccf92a6b7c907647da274722e44ce",
  :block_number=>7411112}]
[7] pry(main)> cell = cells[1]
=> {:capacity=>1000000,
 :lock=>"0x82e4b4bfb752e1ccd293be2e020f07dee6e792f27259c1c44f8f325eced42b68",
 :out_point=>{:hash=>"0xb9578b4a2e1d6e809dc685c5355ebd0727a8fa5ad7d99d1fdaa54ab0db3c58aa", :index=>0},
 :confirmed=>"0000000000000000000000000000000000000000000000000000000000000000",
 :unconfirmed=>"6afcc9af62d92f1695d3456cc2d818e38b5ccf92a6b7c907647da274722e44ce",
 :block_number=>7411112}
[8] pry(main)> bob.commit_block(chain, cell, 7411113, "f6193be4bccf7484967ce8002ce22459f62ff642fb11be26feea9b34b8382c63")
=> "0xe9442ae2ce4f008cda6b06c138a98f2ca5e685e6df0ac43cee1023610bbb8f7c"
[9] pry(main)> cells = bob.get_block_cells(chain)
=> [{:capacity=>990000,
  :lock=>"0x82e4b4bfb752e1ccd293be2e020f07dee6e792f27259c1c44f8f325eced42b68",
  :out_point=>{:hash=>"0xa721c1c86ba6f0e8e834c56d8fd6a53a0ebd8d82840b8608a4c8647089481eb4", :index=>0},
  :confirmed=>"0000000000000000000000000000000000000000000000000000000000000000",
  :unconfirmed=>"51eb67b96f54f5263dcb102a3f532f9fdde9aa0c2aff4e4f42bda1ad1332081f",
  :block_number=>7411111},
 {:capacity=>1000000,
  :lock=>"0x82e4b4bfb752e1ccd293be2e020f07dee6e792f27259c1c44f8f325eced42b68",
  :out_point=>{:hash=>"0xe9442ae2ce4f008cda6b06c138a98f2ca5e685e6df0ac43cee1023610bbb8f7c", :index=>0},
  :confirmed=>"6afcc9af62d92f1695d3456cc2d818e38b5ccf92a6b7c907647da274722e44ce",
  :unconfirmed=>"f6193be4bccf7484967ce8002ce22459f62ff642fb11be26feea9b34b8382c63",
  :block_number=>7411113}]
```
