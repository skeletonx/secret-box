class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    @user = User.from_omniauth(request.env["omniauth.auth"])
    flash[:notice] = I18n.t "devise.omniauth_callbacks.success", :kind => "Google"
    sign_in_and_redirect @user, :event => :authentication
=begin
      if @user.persisted?
        flash[:notice] = I18n.t "devise.omniauth_callbacks.success", :kind => "Google"
        #sign_in(:user, @user) 
        #redirect_to welcome_path
        sign_in_and_redirect @user, :event => :authentication
      else
        # session["devise.google_data"] = request.env["omniauth.auth"]
        #redirect_to new_user_registration_url
        flash[:notice] = "Signing up with google+"
        @user.save
        sign_in_and_redirect @user, :event => :authentication
      end
=end
  end
  
  def facebook
    @user = User.from_omniauth(request.env["omniauth.auth"])
    flash[:notice] = I18n.t "devise.omniauth_callbacks.success", :kind => "Facebook"
    sign_in_and_redirect @user, :event => :authentication
  end
end