class MailingsController < ApplicationController
  before_filter :require_user
  before_filter :set_current_tab
  before_filter :auto_complete, :only => :auto_complete

  # GET /mailings
  # GET /mailings.xml                                                   HTML
  #----------------------------------------------------------------------------
  def index
    @mailings = get_mailings
    
    respond_to do |format|
      format.html # index.html.haml
      format.js   # index.js.rjs
      format.xml  { render :xml => @mailings }
    end
  end

  # GET /mailings/1
  # GET /mailings/1.xml
  #----------------------------------------------------------------------------
  def show
    #@mailing = Mailing.find(params[:id])
    @mailing = Mailing.my(@current_user).find(params[:id])
    @mailing_mails = MailingMail.find(:all, :conditions => { :mailing_id => @mailing.id }, :include => :mailable)

    respond_to do |format|
      format.html # show.html.haml
      format.xml  { render :xml => @mailing }
    end
  end

  # GET /mailings/new
  # GET /mailings/new.xml                                               AJAX
  #----------------------------------------------------------------------------
  def new
    @mailing = Mailing.new(:user => @current_user, :access => Setting.default_access)
    @users = User.except(@current_user).all
    
    respond_to do |format|
      format.js   # new.js.rjs
      format.xml  { render :xml => @mailing }
    end
  end

  # GET /mailings/1/edit                                                AJAX
  #----------------------------------------------------------------------------
  def edit
    @mailing = Mailing.my(@current_user).find(params[:id])
    @users = User.except(@current_user).all
    
    if params[:previous] =~ /(\d+)\z/
      @previous = Mailing.find($1)
    end

  rescue ActiveRecord::RecordNotFound
    @previous ||= $1.to_i
    respond_to_not_found(:js) unless @mailing
  end

  # POST /mailings
  # POST /mailings.xml                                                  AJAX
  #----------------------------------------------------------------------------
  def create   
    @mailing = Mailing.new(params[:mailing])
    @users = User.except(@current_user).all
    
    respond_to do |format|
      if @mailing.save_with_permissions(params[:users])
        if params[:mailing_related_source]
          model = params[:mailing_related_source].singularize.camelize
          query = session[:"#{params[:mailing_related_source]}_current_query"]
          insert_mails(@mailing, model, query) 
        end       
        @mailings = get_mailings
        format.js   # create.js.rjs
        format.xml  { render :xml => @mailing, :status => :created, :location => @mailing }
      else
        format.js   # create.js.rjs
        format.xml  { render :xml => @mailing.errors, :status => :unprocessable_entity }
      end
    end   
  end

  # PUT /mailings/1
  # PUT /mailings/1.xml                                                 AJAX
  #----------------------------------------------------------------------------
  def update
    @mailing = Mailing.my(@current_user).find(params[:id])

    respond_to do |format|
      if @mailing.update_with_permissions(params[:mailing], params[:users])
        format.js   # update.js.rjs
        format.xml  { head :ok }
      else
        @users = User.except(@current_user).all
        format.js   # update.js.rjs
        format.xml  { render :xml => @mailing.errors, :status => :unprocessable_entity }
      end
    end

  rescue ActiveRecord::RecordNotFound
    respond_to_not_found(:js, :xml)
  end

  # GET /mailings/1/confirm                                             AJAX
  #----------------------------------------------------------------------------
  def confirm
    @mailing = Mailing.find(params[:id])

  rescue ActiveRecord::RecordNotFound
    respond_to_not_found(:js, :xml)
  end

  # DELETE /mailings/1
  # DELETE /mailings/1.xml                                              AJAX
  #----------------------------------------------------------------------------
  def destroy
    @mailing = Mailing.my(@current_user).find(params[:id])
    @mailing.destroy if @mailing

    respond_to do |format|
      format.html { respond_to_destroy(:html) }
      format.js   { respond_to_destroy(:ajax) }
      format.xml  { head :ok }
    end

  rescue ActiveRecord::RecordNotFound
    respond_to_not_found(:html, :js, :xml)
  end 
  
  private
  #----------------------------------------------------------------------------
  def get_mailings
    Mailing.my(@current_user).find(:all)
  end
  
  #----------------------------------------------------------------------------
  def respond_to_destroy(method)
    if method == :ajax
      @mailings = get_mailings
      if @mailings.blank?
        @mailings = get_mailings(:page => current_page - 1) if current_page > 1
        render :action => :index and return
      end
      # At this point render default destroy.js.rjs template.
    else # :html request
      self.current_page = 1 # Reset current page to 1 to make sure it stays valid.
      flash[:notice] = "#{t(:asset_deleted, @mailing.name)}"
      redirect_to(mailings_path)
    end
  end
 
end