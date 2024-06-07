class ResumesController < ApplicationController
  def new
    @resume = Resume.new
  end

  def create
    @resume = Resume.new(resume_params)
    if @resume.save
      redirect_to @resume
    else
      render :new
    end
  end

  def show
    @resume = Resume.find(params[:id])
    @analysis = @resume.analyze_text
  end

  private

  def resume_params
    params.require(:resume).permit(:file)
  end
end
