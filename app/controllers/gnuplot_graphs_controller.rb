class GnuplotGraphsController < ApplicationController
	def index
		ENV["RB_GNUPLOT"] = "/usr/local/bin/gnuplot"

		@gnuplot = GnuplotLineChart.new(:location => params[:location] || "福島第一原子力発電所", :start_date => params[:start_date], :end_date => params[:end_date])

		respond_to do |format|
			format.html { render(:inline => "<%= @gnuplot.plot('html') %>", :layout => false) }
			format.svg { render(:inline => "<%= @gnuplot.plot('svg') %>", :layout => false) }
			format.png { send_data(@gnuplot.plot('png'), :type => "image/png", :disposition => "inline") }
			format.pdf { send_data(@gnuplot.plot('pdf'), :type => "application/pdf", :disposition => "inline") }
		end
	end

	def search
		@locations = Radiation.find(:all, :select => "DISTINCT location", :order => "location")
	end
end
