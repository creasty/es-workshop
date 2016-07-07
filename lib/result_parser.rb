class ResultParser

  def parse(res)
    Array(res.dig('hits', 'hits')).map do |raw_hit|
      hit = base_hit(raw_hit)

      inner_hits = Hash.new { |h, k| h[k] = [] }

      Array(raw_hit['inner_hits']).each do |name, r|
        kind, _ = name.split('.')
        hits = parse(r)
        inner_hits[kind].push(*hits)
      end

      inner_hits.each do |k, hits|
        hits = hits.sort_by { |h| -h[:score] }

        case k
        when 'has_child'
          hit[:child_hits] = hits
        when 'has_parent'
          hit[:parent_hits] = hits
        else
          hits.each do |h|
            h[:highlight].each do |field, hl|
              (hit[:highlight][field] ||= []).push(*hl)
            end
          end
        end
      end

      hit
    end
  end

  def base_hit(h)
    (h['fields'] || {}).merge(
      type:      h['_type'].to_sym,
      id:        h['_id'].to_i,
      score:     h['_score'],
      highlight: h['highlight'] || {},
    )
  end

end
