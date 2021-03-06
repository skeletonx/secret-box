class OrdersController < ApplicationController
  before_action :setup_gon_variables
  protect_from_forgery except: [:paypal_payment_confirm]

  def new
    @album = Album.friendly.find(params[:album_id])
    @order = @album.orders.new
    authorize @order
    @sample_album = @album.sample_album
    @sample_picture = SamplePicture.find_by_size(@album.sample_album.photo_size)
    @picture_total = (@album.pictures.count * @sample_picture.price).round(2)

    #gon.controller = model_name

  end
  
  def create
    @album = Album.friendly.find(params[:album_id])
    @sample_album = @album.sample_album
    @sample_picture = SamplePicture.find_by_size(@album.sample_album.photo_size)
    @order = Order.new(order_params)
    @order.album = @album
    authorize @order
    @order.user = current_user

    # set order status to "submitted"
    @order.status = "Pending"
    
    if @order.save
      redirect_to checkout_order_path(@order)
    else
      render :new
    end
  end
  
  def edit    
    @order = Order.friendly.find(params[:id])
    authorize @order
    @album = @order.album
    @sample_album = SampleAlbum.find(@album.style)
    @sample_picture = SamplePicture.find_by_size(@album.sample_album.photo_size)
   # @picture_total = @album.photos_inserted.count * @sample_picture.price
    
  end
  
  def update
    #@album = Album.friendly.find(params[:album_id])
    @order = Order.friendly.find(params[:id])
    authorize @order
    
    params[:order][:options] = [] if params[:order][:options].blank?
    
    
    if @order.update_attributes(order_params)
      flash[:notice] = "Order was updated"
      redirect_to checkout_order_path(@order)
    else
      flash.now[:error] = "Error updating order"
      render :edit
    end
  end
  
  def destroy
    #@album = Album.friendly.find(params[:album_id])
    @order = Order.friendly.find(params[:id])
    authorize @order
    if @order.status == "Pending"
      @order.destroy
      flash[:notice] = "order #{@order.album.name} was deleted."
    else
      flash[:error] = "order cannot deleted at this time."
    end
    
    redirect_to order_management_index_path
  end

  def checkout
    #@shipping_address = 
    #@album = Album.friendly.find(params[:album_id])
    @order = Order.friendly.find(params[:id])
    authorize @order
    @album = @order.album
    @sample_album = @album.sample_album
    @sample_picture = SamplePicture.find_by_size(@album.sample_album.photo_size)
    @shipment = ServiceLookup.find_by_name(@order.shippment)
  end
  
  def confirm
    @order = Order.friendly.find(params[:id])
    authorize @order
  end
  
  def stripe_payment_confirm
    @order = Order.friendly.find(params[:id])
    authorize @order
    @amount = (@order.total_price * 100).round
    customer = Stripe::Customer.create(
      :email => params[:stripeEmail],
      :source  => params[:stripeToken]
      )

    charge = Stripe::Charge.create(
      :customer    => customer.id,
      :amount      => @amount,
      :description => 'Secrect Album Order',
      :currency    => 'usd'
      )
    
    @shipping_address = ShippingAddress.new(name: params[:stripeShippingName], address_line1: params[:stripeShippingAddressLine1],
      state: params[:stripeShippingAddressState], city: params[:stripeShippingAddressCity], zipcode: params[:stripeShippingAddressZip])
    @shipping_address.order = @order    
    
    @order.status = "Submitted"
    # update number of sample album in store
    @order.update_number_in_stock
    @order.save
    @shipping_address.save
    UserNotifier.send_order_received_email(current_user, @order).deliver_now
    UserNotifier.send_order_received_email_to_system(current_user, @order).deliver_now
    
    redirect_to confirm_order_path(@order)

    
    rescue Stripe::CardError => e
      flash[:error] = e.message
      redirect_to checkout_order_path(@order)
  end
  
  def paypal_payment_confirm
    @order = Order.friendly.find(params[:id])
    #authorize @order
    params.permit!
    status = params[:payment_status]
    
    if status == "Completed" && @order.paypal_valid?(params, request.raw_post)
      @shipping_address = ShippingAddress.new(name: params[:address_name], address_line1: params[:address_street], state: params[:address_state], city: params[:address_city], zipcode: params[:address_zip])
      @shipping_address.order = @order    
    
      @order.status = "Submitted"
      # update number of sample album in store
      @order.update_number_in_stock
      @order.save
      @shipping_address.save
      UserNotifier.send_order_received_email(@order.user, @order).deliver_now
      UserNotifier.send_order_received_email_to_system(@order.user, @order).deliver_now      
    end
    render nothing: true
  end
  
  def cancel
    @order = Order.friendly.find(params[:id])
    if @order.status == "Submitted"
      @order.status = "Request Cancelation"
      UserNotifier.send_order_cancel_request_email_to_system(current_user, @order).deliver_now
      UserNotifier.send_order_cancel_request_email(current_user, @order).deliver_now
    else
      @order.status = "Submitted"
      UserNotifier.send_order_undo_cancel_request_email_to_system(current_user, @order).deliver_now
      UserNotifier.send_order_undo_cancel_request_email(current_user, @order).deliver_now
    end
    if @order.save
      redirect_to order_management_index_path
    end
  end

  private
  
  def order_params
    params.require(:order).permit(:shippment, :carrier, :tracking_number, 
      :total_price, :status, :options =>[])
  end

  def shipping_address_params
    params.permit(:stripeShippingName, :stripeShippingAddressLine1, :stripeShippingAddressState, 
      :stripeShippingAddressCity, :stripeShippingAddressZip)
  end
  
  def setup_gon_variables
    @options = ServiceLookup.where(categories: "option")
    @shipments = ServiceLookup.where(categories: "shipment")
    # information to set option checkbox behavior in coffeescript
    gon.options = Order.display_options
    gon.option_id_prefix = [controller_name.classify.downcase, :options.to_s, ""].join("_")
    
    # information to set shipment radio in coffeescript
    gon.shipments = @shipments
    gon.shipment_id_prefix = [controller_name.classify.downcase, :shippment.to_s, ""].join("_")
  end
end
