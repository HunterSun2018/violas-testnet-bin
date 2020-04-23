use 0x7257c2417e4d1038e1817c8f283ace2e::ViolasToken;

fun main(maker: address, orderidx: u64, idxa: u64, amounta: u64, idxb: u64, amountb: u64, data: vector<u8>) {
    ViolasToken::take_order(maker, orderidx, idxa, amounta, idxb, amountb, data)
}
