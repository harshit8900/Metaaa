<aura:component controller="ContactController" implements="flexipage:availableForAllPageTypes,force:appHostable">
    <aura:attribute name="contact" type="Contact" default="{ 'sobjectType': 'Contact' }"/>
    <aura:attribute name="message" type="String"/>
    <aura:attribute name="isSuccess" type="Boolean" default="false"/>

    <lightning:card title="Create New Contact" iconName="standard:contact">
        <div class="slds-p-around_medium">
            <lightning:input label="First Name" value="{!v.contact.FirstName}" />
            <lightning:input label="Last Name" value="{!v.contact.LastName}" required="true"/>
            <lightning:input label="Email" type="email" value="{!v.contact.Email}" />
            <lightning:input label="Phone" value="{!v.contact.Phone}" />
            <lightning:input label="Fax" value="{!v.contact.Fax}" />

            <lightning:button label="Save Contact" variant="brand" onclick="{!c.handleSave}" class="slds-m-top_medium"/>
        </div>

        <aura:if isTrue="{!not(empty(v.message))}">
            <div class="slds-p-around_medium">
                <aura:if isTrue="{!v.isSuccess}">
                    <div class="slds-text-color_success">{!v.message}</div>
                <aura:set attribute="else">
                    <div class="slds-text-color_error">{!v.message}</div>
                </aura:set>
                </aura:if>
            </div>
        </aura:if>

    </lightning:card>
</aura:component>
