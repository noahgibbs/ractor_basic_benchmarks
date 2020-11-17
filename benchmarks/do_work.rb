def mandel_check(c, iters)
  (1..(iters-1)).inject(c) { |total, item| total * total + item }
end

def do_work
    check_vals = [-1.0, -0.75, -0.5, -0.25, 0, 0.25, 0.5, 0.75, 0.1 ]
    check_points = check_vals.flat_map { |i| check_vals.map { |r| Complex(r, i) } }
    check_points.map do |c|
        mandel_check(c, 8)
    end.map(&:inspect).join(",")
end
