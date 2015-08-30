def parse_www_encoded_form(www_encoded_form)
  URI::decode_www_form(www_encoded_form).each do |pair|
    keys = parse_key(pair.first)
    if keys.is_a?(Array)
      @params.merge!(build_chain(keys, pair[1])) { |_, v1, v2| merger(v1, v2) }
    else
      @params.merge!(keys[first] => pair[1])
    end
  end
end

def build_chain(arr, val)
  return val if arr.length < 1
  a = {}

  {arr.first => build_chain(arr.drop(1), val)}
end

def merger(v1, v2)
  return v1.merge(v2) {|k, a, b| merger(a, b)}
end
# this should return an array
# user[address][street] should return ['user', 'address', 'street']
# def parse_key(key)
#   key.split(/(\[|\])/).reject {|val| val == ""|| val == "[" || val == "]" }
# end
