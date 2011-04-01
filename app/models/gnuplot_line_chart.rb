class GnuplotLineChart
	attr_reader(:location)

	def initialize(options={})
		conditions = {}
		conditions[:location] = (@location = options[:location])
		if options[:start_date].present?
			if options[:end_date].present?
				conditions[:measured_at] = (options[:start_date]..options[:end_date])
			else
				conditions[:measured_at] = (options[:start_date]..Date.tomorrow.to_s)
			end
		else
			if options[:end_date].present?
				conditions[:measured_at] = ("2011-03-10"..options[:end_date])
			else
			end
		end

		if options[:place]
			places = [options[:place]]
		else
			places = Radiation.find(:all, :select => "DISTINCT place", :conditions => conditions).map(&:place)
		end

		@radiations = []
		places.each do |place|
			@radiations << Radiation.find(:all, :conditions => conditions.merge(:place => place), :order => "measured_at")
		end
	end

	def plot(type)
		case type
		when "png"
			terminal = "png font '/usr/local/share/fonts/std.ja_JP/Gothic' size 1280, 960"
		when "svg"
			terminal = "svg font '/usr/local/share/fonts/std.ja_JP/Gothic' size 1280, 960"
		when "pdf"
			terminal = "pdfcairo font ',10' size 42.0cm, 29.7cm"
		when "html"
			terminal = "canvas standalone mousing jsdir 'http://cyanogen.jp/monitoring/gnuplot/' title '福島第一原子力発電所モニタリングカー'"
		else
			raise("unknown content type: #{type}")
		end

		#$VERBOSE = true

		Gnuplot.open(false) do |gp|
			Gnuplot::Plot.new(gp) do |plot|
				plot.terminal(terminal)
				plot.output("/dev/stdout")

				plot.title(@location)
				plot.xlabel("日時")
				plot.ylabel("γ線線量率(μSv/h)")
				plot.xdata("time")
				plot.logscale("y")
				#plot.xtics('("2011-03-25", "2011-03-26", "2011-03-27", "2011-03-28", "2011-03-29")')
				#plot.xrange('["2011-03-25":"2011-03-29"]')
				plot.format('x "%m/%d\n%H:%M"')
				plot.timefmt('"%Y-%m-%d %H:%M:%S"')

				@radiations.each_with_index do |radiation, i|
					plot.data << Gnuplot::DataSet.new([radiation.map{|r| r.measured_at.strftime("%Y-%m-%d %H:%M:%S")}, radiation.map(&:gamma_ray)]) do |ds|
						ds.title = radiation.first.place
						ds.with = "linespoints pointtype #{i + 1}"
						ds.using = "1:3"
					end
				end
			end
		end
	end
end
