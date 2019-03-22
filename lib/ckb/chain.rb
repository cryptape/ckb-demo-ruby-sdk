require_relative "api"
require_relative 'utils'

require "secp256k1"
require "securerandom"

module Ckb
  BLOCK_UNLOCK_SCRIPT = File.read(File.expand_path("../../../scripts/blocks/unlock.rb", __FILE__))
  BLOCK_CONTRACT_SCRIPT = File.read(File.expand_path("../../../scripts/blocks/contract.rb", __FILE__))

  class Chain
    attr_reader :api
    attr_reader :name
    attr_reader :pubkey

    def initialize(api, name, pubkey)
      @api = api
      @name = name
      @pubkey = pubkey
    end

    def unlock_script_json_object(pubkey)
      {
        version: 0,
        reference: api.mruby_cell_hash,
        signed_args: [
          BLOCK_UNLOCK_SCRIPT,
          name,
          pubkey
        ],
        args: []
      }
    end

    def contract_script_json_object
      {
        version: 0,
        reference: api.mruby_cell_hash,
        signed_args: [
          BLOCK_CONTRACT_SCRIPT,
          name,
          self.pubkey
        ],
        args: []
      }
    end

    def contract_type_hash
      Ckb::Utils.json_script_to_type_hash(self.contract_script_json_object)
    end

    def unlock_type_hash
      Ckb::Utils.json_script_to_type_hash(self.unlock_script_json_object(self.pubkey))
    end

    def to_json
      {
        api: api.uri.to_s,
        name: name,
        pubkey: self.pubkey
      }.to_json
    end

    def self.from_json(json)
      o = JSON.parse(json, symbolize_names: true)
      Chain.new(Ckb::Api.new(host: o[:api]), o[:name], o[:pubkey])
    end
  end
end