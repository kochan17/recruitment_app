class ResumesController < ApplicationController
  def new
    @resume = Resume.new
  end

  def create
    @resume = Resume.new(resume_params)
    if @resume.save
      redirect_to @resume
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @resume = Resume.find(params[:id])
    @text = @resume.extract_text
  end

  private

  def resume_params
    params.require(:resume).permit(:title, :file)
  end
end
