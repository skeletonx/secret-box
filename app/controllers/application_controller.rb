class ApplicationController < ActionController::Base
  include Pundit
  protect_from_forgery with: :exception
  before_action :configure_permitted_parameters, if: :devise_controller?
 
  #rescue_from Pundit::NotAuthorizedError do |exception|
  #   redirect_to root_url, alert: exception.message
  # end
  
  def after_sign_in_path_for(resource)
    welcome_path
  end
  
  protected
 
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :email])
  end
  
end
