class OrderManagementController < ApplicationController
  def index
    authorize :order_management, :index?
    @orders =  Order.where(user_id: current_user.id).page(params[:page]).per(5).order(created_at: :desc)
    #all.paginate(page: params[:page], per_page: 5)
  end

  def show
  end
  
  def admin_index
    authorize :order_management, :admin_index?
    @orders = Order.page(params[:page]).per(10).order(created_at: :desc)
    #all.paginate(page: params[:page], per_page: 10)
  end
  
  def edit
    authorize :order_management, :edit?
    @order = Order.friendly.find(params[:id])
  end
  
  def update
    authorize :order_management, :update?
    @order = Order.friendly.find(params[:id])
    
    if @order.update_attributes(order_params)
      # if update status is equal to In Progress, send "in progress" notification to user
      if @order.status == "In Progress"
        UserNotifier.send_order_in_progress_email(@order.user, @order).deliver_now
      end
      # if update status is equal to Shipped, send "shipped" notification to user
      if @order.status == "Shipped"
        UserNotifier.send_order_shipped_email(@order.user, @order).deliver_now
      end
      
      #if update status is Cancel Request, send refund notice
      if @order.status == "Cancel"
        UserNotifier.send_order_cancel_confirm_email(@order.user, @order).deliver_now
      end
      flash[:notice] = "Order was updated"
      redirect_to order_management_edit_path(@order)
    else
      flash.now[:error] = "Error occur in Updating order"
      render :edit
    end
    
  end
  
  def download
    authorize :order_management, :download?
    require 'rubygems'
    require 'zip'
    @order = Order.friendly.find(params[:id])
    filename = @order.user.name + "_" + @order.album.name + "_" + @order.created_at.to_formatted_s(:number) + ".zip"
    temp_file = Tempfile.new(filename)
    
    begin
      Zip::OutputStream.open(temp_file) {|zos|}
      
      Zip::File.open(temp_file.path, Zip::File::CREATE) do |zip|
        if @order.album.front_cover
          zip.add("front_cover.jpg", open(@order.album.front_cover))
        end
        @order.album.photos.each do |photo|
          if @order.album.sample_album.orientation == "landscape"
            if photo.picture.context.url
              zip.add("photo"+photo.photo_number.to_s+".jpg", open(photo.picture.context.url))
            end
          else
            if photo.picture.context.portrait.url
              zip.add("photo"+photo.photo_number.to_s+".jpg", open(photo.picture.context.portrait.url))
            end
          end
        end
      end
      
      zip_data = File.read(temp_file.path)
      
      send_data(zip_data, type: 'application/zip', filename: filename)
    ensure
      temp_file.close
      temp_file.unlink
    
#    data = open("https://skeletonx-lazyalbum.s3.amazonaws.com/uploads/album/avatar/4/album.jpg")
    #send_file , type: 'imgae/jpg', x_sendfile: true
#    send_data data.read, filename: "something.jpg", type: "image/jpg"
    end
  end
  
  def order_params
    params.require(:order).permit(:carrier, :track_number, :status)
  end
  
end
