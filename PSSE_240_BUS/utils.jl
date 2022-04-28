function find_max_key(d::Dict, metric)

    maxval = first([v[metric] for v in values(d)])
    maxkey = first(keys(d))
    for key in keys(d)
        mvalue = d[key][metric]
        if d[key][metric] >= maxval
            maxkey = key
            maxval = mvalue
        end
    end

    return maxval, maxkey
end

function find_min_key(d::Dict, metric)

    minval = first([v[metric] for v in values(d)])
    minkey = first(keys(d))
    for key in keys(d)
        if d[key] <= minval
            minkey = key
            minval = d[key]
        end
    end

    return minval, minkey
end

function pm_branch_name(device_dict, bus_f, bus_t)
    if device_dict["source_id"][1] == "branch"
        index = device_dict["source_id"][4]
    elseif device_dict["source_id"][1] == "transformer"
        index = device_dict["source_id"][5]
    else
        @error "Can't determine right index $(device_dict)"
        index = device_dict["index"]
    end
    @show "$(get_name(bus_f))-$(get_name(bus_t))-i_$index"
    return "$(get_name(bus_f))-$(get_name(bus_t))-i_$index"
end
