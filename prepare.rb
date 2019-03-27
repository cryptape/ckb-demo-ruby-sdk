require_relative "lib/ckb/wallet"

api = Ckb::Api.new
tip_number = api.get_tip_number

p "Install mruby contract"
p "waiting..."

asw = Ckb::AlwaysSuccessWallet.new(api)

conf = asw.install_mruby_cell!("./processed_argv_source_entry")

while !asw.configuration_installed?(conf)
    sleep 1
end

api.set_and_save_default_configuration!(conf)
p "Success!"
puts "\n\n"

bob = Ckb::Wallet.from_hex(api, "e79f3207ea4980b7fed79956d5934249ceac4751a4fae01a0f7c4a96884bc4e3")

raise "Bob initial balance should be 0, but got #{bob.get_balance}" unless bob.get_balance == 0

p "Bob's initial balance is 0"
p "ASW transfers 1000000 capacity"
p "waiting..."

asw.send_capacity(bob.address, 1000000)

while bob.get_balance != 1000000
    sleep 1
end

p "Success!"
puts "\n\n"

token_info = bob.created_token_info("Token 1")
bob_token1 = bob.udt_wallet(token_info)

p "Bob creates UDT-Token"
p "waiting..."
bob.create_udt_token(10000, "Token 1", 10000000)

while bob_token1.get_balance != 10000000
    sleep 1
end

p "Success!"
puts "\n\n"
