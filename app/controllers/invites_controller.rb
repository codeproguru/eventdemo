class InvitesController < ApplicationController
  before_filter :authorize, :except => [:cron_invite_email]
  before_filter :event_authorize, :except => [:add_guests, :edit_guest, :delete_guest, :delete, :cron_invite_email]
  
  def index
      @meta_title = I18n.t 'meta_title.invite_list'
      @user = User.find(session[:user_id])
      @site = SiteSetting.find(:first)
      @event = Event.find(params[:id])
      
      @schedules_invite = Invite.find(:all, :conditions => ['event_id=? AND draft=?', @event[:id], 0])
      @draft_invite = Invite.find(:all, :conditions => ['event_id=? AND draft=?', @event[:id], 1])
  end
  
  def create
      @meta_title = I18n.t 'meta_title.create_invite'
      @user = User.find(session[:user_id])
      @site = SiteSetting.find(:first)
      @event = Event.find(params[:id])
      if params[:invitation_id]!=nil && params[:invitation_id]!=''
        @invite = Invite.find(params[:invitation_id])
        @random = '0'
        @guests = InviteGuest.find(:all, :conditions => ['invite_id=?', params[:invitation_id]])
      else
        @invite = Invite.new  
        @random = SecureRandom.hex(10)
        @guests = InviteGuest.find(:all, :conditions => ['random_no=?', @random])
      end
      
      if request.post?  #### Post start
        
        if params[:invitation_id]=='' || params[:invitation_id]==nil
            @invite = Invite.new(params[:invite])
            @invite.save
            @guest = InviteGuest.where(:random_no => params[:random_no]).update_all(:invite_id => @invite[:id], :random_no => '0')
            
        else
            @invite = Invite.find(params[:invitation_id])
            @invite.update_attributes(params[:invite])
           
        end
        
        
        
        if params[:send_email]!=''
                UserMailer.send_invite_email(@invite, params[:send_email], 'Attendee').deliver
                flash[:notice1] = I18n.t 'invite_controller.email_successfully'
                redirect_to(:action=>'create/'+@invite[:event_id].to_s, :invitation_id=> @invite[:id]) 
        else
            if params[:submit_type]=='send'
                @guest = InviteGuest.find(:all, :conditions => ['invite_id=?', @invite[:id]])
                
                if @guest.count > 0
                    for g in @guest
                        if g[:first_name]
                          @name = g[:first_name]+' '+g[:last_name]
                        else
                          @name = '';
                        end
                        
                        UserMailer.send_invite_email(@invite, g[:email], @name).deliver
                        g[:sent] = 1
                        g[:send_date_time] = DateTime.now.strftime('%Y-%m-%d %H:%M:%S')
                        g.save
                    end
                    @invite[:draft]=0
                    @invite[:sent] = 1
                    @invite[:send_date_time] = DateTime.now.strftime('%Y-%m-%d %H:%M:%S')
                    @invite.save
                    
                end
                
                flash[:notice1] = I18n.t 'invite_controller.email_successfully'
                redirect_to(:action=>'index/'+@invite[:event_id].to_s) 
            else
                @invite[:draft]=1
                @invite.save
                flash[:notice1] = I18n.t 'invite_controller.invite_saved_draft_successfully'
                redirect_to(:action=>'index/'+@invite[:event_id].to_s) 
            end
        end
        
      end   #### Post ends
      
  end
  
  def add_guests
     @random = params[:id]
    
      if request.post?
              if(params[:fetch_type]=='files')
                InviteGuest.import(params[:upload], params[:guest])
              end
                
              if(params[:fetch_type]=='manually')
                  ids = params[:emails]
                  
                  @newline = ids.split(/\r\n/)
                    i=0 
                    k=0
                     @newline.each do |n|
                         @commas = @newline[i].split(',')
                          j=0
                           @commas.each do |c|
                             
                               if(@commas[j]!='')
                                 @cons = InviteGuest.new(params[:guest])
                                 @cons[:email] = c
                                 @cons.save
                                 k+=1
                               end
                              j+=1 
                           end
                       i+=1
                     end
                    
              end
              
             if params[:guest][:invite_id]!='' && params[:guest][:invite_id]!=nil && params[:guest][:invite_id]!='0'
                @guests = InviteGuest.find(:all, :conditions => ['invite_id=?', params[:guest][:invite_id]])
             else 
                @guests = InviteGuest.find(:all, :conditions => ['random_no=?', params[:guest][:random_no]])
             end
                
            render :json => { :success => true, :msg => (I18n.t 'contact_controller.success'), :guest => @guests  }
            
      else
        render :layout => false
      end
  end
  
  def edit_guest
      @guest = InviteGuest.find(params[:id])
      if request.post?
           @guest = InviteGuest.find(params[:edit_guest][:id])
           if @guest.update_attributes(params[:edit_guest])
                 
                render :json => { :success => true, :msg => (I18n.t 'contact_controller.success'), :guest => params[:edit_guest]  }
           else
                render :json => { :success => true, :msg => @guest.errors.full_messages[0]}
           end
      else
        render :layout => false
      end
  end
  
  
  def delete_guest
    guest_id = params[:guest_id].split(',')
    for guest in guest_id
      InviteGuest.find(guest).destroy
    end
    
    if params[:invitation_id]!='' && params[:invitation_id]!=nil
      @guests = InviteGuest.find(:all, :conditions => ['invite_id=?', params[:invitation_id]])
    else 
      @guests = InviteGuest.find(:all, :conditions => ['random_no=?', params[:random_no]])
    end
    render :json => { :success => true, :msg => (I18n.t 'contact_controller.success'), :guest => @guests  }
  end
  
  
  def delete
    @inv = Invite.find(params[:id])
    event_id = @inv[:event_id]
    
    InviteGuest.where(:invite_id => @inv[:id]).destroy_all
    @inv.destroy
    
    flash[:notice1] = I18n.t 'invite_controller.invite_deleted'
    redirect_to(:action=>'index/'+event_id.to_s)
  end
  
  
  ####  attendee module #######
  def add_attendee
     @meta_title = I18n.t 'meta_title.add_attendee'
     @user = User.find(session[:user_id])
     @site = SiteSetting.find(:first)
     @event = Event.find(params[:id])
    
     @org_id = @event[:organizer_id]
     
     @event_theme = EventTheme.one_theme(@event[:id])
     if @event_theme
     else @event_theme = Theme.find(:first)
     end
     
     @updates = EventUpdate.find(:all, :conditions => ['event_id=?', @event[:id]])
     @one_theme = @event_theme
  end
  
  
  def attendees
      @meta_title = I18n.t 'meta_title.all_attendees_list'
      @user = User.find(session[:user_id])
      @site = SiteSetting.find(:first)
      @event = Event.find(params[:id])
      @event_attendee = EventAttendee.find(:all, :conditions => ['event_id=?', @event[:id]]).paginate(:page => params[:page], :per_page => 5)
  end
  ####  attendee module end #######
  
   
  ############  cron job ############
  def cron_invite_email
      @invites = Invite.find(:all, :conditions => ['draft=0 AND immediately=0'])
      if @invites.count > 0
        for inv in @invites 
           @eve = Event.find(inv[:event_id])
           now_date = Time.now.strftime('%Y-%m-%d %H:%M')
           @eve_date = @eve[:event_start_date_time]
           
           if inv[:days]!='' && inv[:days]!=nil
             @eve_date = @eve_date - inv[:days].days
           end
           
           if inv[:hours]!='' && inv[:hours]!=nil
             @eve_date = @eve_date - inv[:hours].hours
           end
           
           if inv[:minutes]!='' && inv[:minutes]!=nil
             @eve_date = @eve_date - inv[:minutes].minutes
           end
           
           if inv[:select_date].strftime('%Y-%m-%d %H:%M') == now_date || @eve_date.strftime('%Y-%m-%d %H:%M')==now_date
              
              @guest = InviteGuest.find(:all, :conditions => ['invite_id=?', inv[:id]])
              if @guest.count > 0
                  for g in @guest
                      if g[:first_name]
                        @name = g[:first_name]+' '+g[:last_name]
                      else
                        @name = '';
                      end
                      
                      UserMailer.send_invite_email(inv, g[:email], @name).deliver
                      g[:sent] = 1
                      g[:send_date_time] = DateTime.now.strftime('%Y-%m-%d %H:%M:%S')
                      g.save
                  end ## for guest ends
                  inv[:draft]=0
                  inv[:sent] = 1
                  inv[:send_date_time] = DateTime.now.strftime('%Y-%m-%d %H:%M:%S')
                  inv.save
                  
              end ### if guest ends
           end ### date compare ends  
            
         end ### for ends
      end ### if ends 
      render :text => (I18n.t 'invite_create.done') and return
  end
  
end
