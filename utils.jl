const D3Colors = [
  "#1f77b4"
  "#ff7f0e"
  "#2ca02c"
  "#d62728"
  "#9467bd"
  "#8c564b"
  "#e377c2"
  "#7f7f7f"
  "#bcbd22"
  "#17becf"
]

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
