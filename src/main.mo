import Trie "mo:base/Trie";
import List "mo:base/List";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import Error "mo:base/Error";
import NNSType "./nns";

shared(install) actor class Tax() {
    type NeuronInfo = { timestamp : Int; maturity : Nat64; staked : Nat64 };
    type NeuronMap = Trie.Trie<Nat64, List.List<NeuronInfo>>;
    func key(t: Nat64) : Trie.Key<Nat64> { { key = t; hash = hashNat64 t } };
    
    stable var owner = install.caller;
    stable var neuron_map : NeuronMap = Trie.empty();
    stable var last_update : Int = 0;
    let NNS : NNSType.Self = actor "rrkah-fqaaa-aaaaa-aaaaq-cai";

    public shared(msg) func track(neuron_id : Nat64) : async () {
        if (msg.caller != owner) {
            throw Error.reject("not authorized");
        };
        switch (Trie.get(neuron_map, key neuron_id, Nat64.equal)) {
        case null { neuron_map := Trie.put(neuron_map, key neuron_id, Nat64.equal, List.nil()).0; };
        case (?_) { throw Error.reject("already tracked"); };
        };
    };

    public query(msg) func dump(neuron_id : Nat64) : async [NeuronInfo] {
        if (msg.caller != owner) {
            throw Error.reject("not authorized");
        };        
        switch (Trie.get(neuron_map, key neuron_id, Nat64.equal)) {
        case null { throw Error.reject("neuron not found"); };
        case (?list) { List.toArray(list); };
        };
    };

    public shared(msg) func force_update() : async () {
        if (msg.caller != owner) {
            throw Error.reject("not authorized");
        };
        await fetch();
    };

    /*system func heartbeat() : async () {
        let now = Time.now();
        let elapsed_seconds = (now - last_update) / 1_000_000_000;
        if (elapsed_seconds < 3600 * 24) {
            return;
        };
        await fetch();
    };*/

    func fetch() : async () {
        let now = Time.now();
        last_update := now;
        for ((id, list) in Trie.iter(neuron_map)) {
            let result = await NNS.get_full_neuron(id);
            switch result {
            case (#Ok(info))
            {
                let item = { timestamp = now; maturity = info.maturity_e8s_equivalent; staked = info.cached_neuron_stake_e8s };
                let new_list = List.push(item, list);
                neuron_map := Trie.put(neuron_map, key id, Nat64.equal, new_list).0;
            };
            case (#Err(_)) {};
            };
        };
    };

    func hashNat64(x : Nat64) : Nat32 {
        Text.hash(Nat64.toText(x))
    };
}
